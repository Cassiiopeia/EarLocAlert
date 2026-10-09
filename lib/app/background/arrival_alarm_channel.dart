import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/platform/channel_names.dart';

/// 잠금 화면 알람 권한 상태 (이슈 #235). 네이티브 문자열과 1:1 이다
enum ArrivalAlarmAuthorization {
  notDetermined,
  denied,
  authorized,

  /// iOS 26 미만이거나 AlarmKit 없이 빌드됐다 — 알림과 진동만 쓴다
  unsupported;

  static ArrivalAlarmAuthorization parse(Object? raw) => switch (raw) {
    'notDetermined' => notDetermined,
    'denied' => denied,
    'authorized' => authorized,
    _ => unsupported,
  };
}

/// 잠금 화면 알람을 쓸 수 있는가
class ArrivalAlarmStatus {
  const ArrivalAlarmStatus({
    required this.supported,
    required this.authorization,
  });

  static const unsupported = ArrivalAlarmStatus(
    supported: false,
    authorization: ArrivalAlarmAuthorization.unsupported,
  );

  /// 이 기기·빌드에 AlarmKit 이 있는가 (iOS 26+)
  final bool supported;
  final ArrivalAlarmAuthorization authorization;

  bool get usable =>
      supported && authorization == ArrivalAlarmAuthorization.authorized;
}

/// 잠금 화면 전체를 덮는 무음 알람 (이슈 #235, 결정 057)
///
/// 플랫폼 API 를 인터페이스 뒤에 둔다 (docs/02-ARCHITECTURE.md 규칙 3) —
/// 띄우고 끄는 순서를 실기기 없이 테스트한다.
abstract interface class ArrivalAlarmPlatform {
  Future<ArrivalAlarmStatus> status();

  /// 권한을 묻는다. 이미 정해졌으면 OS 가 다시 묻지 않고 그 값을 돌려준다
  Future<ArrivalAlarmAuthorization> requestAuthorization();

  /// 알람을 띄우고 그 id 를 돌려준다. 실패하면 던진다.
  /// [openLabel] 은 앱 알림 화면으로 들어가는 보조 버튼 문구다 (이슈 #241)
  Future<String> present({
    required String title,
    required String stopLabel,
    required String openLabel,
  });

  /// 이 앱이 띄운 알람을 모두 끈다. 던지지 않는다
  Future<void> stopAll(String reason);

  /// 거부한 권한을 다시 켜러 앱 설정을 연다
  Future<void> openSettings();

  /// 사용자가 잠금 화면에서 알람을 껐을 때 부를 처리기
  void setStopHandler(Future<void> Function(String id) onStopped);
}

/// AlarmKit 이 없는 플랫폼(Android) — 아무것도 띄우지 않는다
class UnsupportedArrivalAlarm implements ArrivalAlarmPlatform {
  const UnsupportedArrivalAlarm();

  @override
  Future<ArrivalAlarmStatus> status() async => ArrivalAlarmStatus.unsupported;

  @override
  Future<ArrivalAlarmAuthorization> requestAuthorization() async =>
      ArrivalAlarmAuthorization.unsupported;

  @override
  Future<String> present({
    required String title,
    required String stopLabel,
    required String openLabel,
  }) => Future.error(UnsupportedError('arrival alarm'));

  @override
  Future<void> stopAll(String reason) async {}

  @override
  Future<void> openSettings() async {}

  @override
  void setStopHandler(Future<void> Function(String id) onStopped) {}
}

/// Swift `ArrivalAlarm` 과 맺은 채널 구현
class ArrivalAlarmChannel implements ArrivalAlarmPlatform {
  const ArrivalAlarmChannel();

  static const _channel = MethodChannel(ChannelNames.arrivalAlarm);

  @override
  Future<ArrivalAlarmStatus> status() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('status');
      return ArrivalAlarmStatus(
        supported: raw?['supported'] == true,
        authorization: ArrivalAlarmAuthorization.parse(raw?['authorization']),
      );
    } on Object catch (error) {
      // 모르면 없는 것으로 본다 — 알림과 진동은 그대로 간다
      Diagnostics.log('alarm', 'status failed error=$error');
      return ArrivalAlarmStatus.unsupported;
    }
  }

  @override
  Future<ArrivalAlarmAuthorization> requestAuthorization() async {
    try {
      return ArrivalAlarmAuthorization.parse(
        await _channel.invokeMethod<String>('requestAuthorization'),
      );
    } on Object catch (error) {
      Diagnostics.log('alarm', 'authorization request failed error=$error');
      return ArrivalAlarmAuthorization.unsupported;
    }
  }

  @override
  Future<String> present({
    required String title,
    required String stopLabel,
    required String openLabel,
  }) async {
    final id = await _channel.invokeMethod<String>('present', {
      'title': title,
      'stopLabel': stopLabel,
      'openLabel': openLabel,
    });
    if (id == null) throw StateError('no alarm id');
    return id;
  }

  @override
  Future<void> stopAll(String reason) async {
    try {
      await _channel.invokeMethod<void>('stopAll', {'reason': reason});
    } on Object catch (error) {
      // 남은 알람은 사용자가 직접 끌 수 있다 — 해제 흐름을 막지 않는다
      Diagnostics.log('alarm', 'stop all failed reason=$reason error=$error');
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on Object catch (error) {
      Diagnostics.log('alarm', 'open settings failed error=$error');
    }
  }

  @override
  void setStopHandler(Future<void> Function(String id) onStopped) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onAlarmStopped') return null;
      final id = (call.arguments as Map?)?['id'] as String?;
      // 경계를 넘어온 순간을 남긴다 — 처리기가 실패해도 받았다는 사실은 남는다
      Diagnostics.log('alarm', 'stop received from native id=$id');
      if (id == null) return null;
      try {
        await onStopped(id);
      } on Object catch (error) {
        Diagnostics.log('alarm', 'stop handling failed id=$id error=$error');
      }
      return null;
    });
  }
}
