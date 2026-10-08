import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/platform/channel_names.dart';
import '../../features/geofence/domain/position_sample.dart';
import '../../features/geofence/domain/watch_tier.dart';

/// 네이티브 적응형 감시를 켜고 끄는 경계 (이슈 #231)
///
/// 플랫폼 API 를 인터페이스 뒤에 둔다 (docs/02-ARCHITECTURE.md 규칙 3) —
/// [IosAdaptiveWatch] 의 단계 전환·판정 연결을 실기기 없이 테스트한다.
abstract interface class IosWatchPlatform {
  /// 측정을 받을 처리기를 단다. 달기 전에 받은 측정은 네이티브가 쥐고 있다가 넘긴다.
  Future<void> attach(Future<void> Function(PositionSample sample) onFix);

  /// 감시를 시작한다. 시작하지 못했으면 그 사유(예: `not_always`)를 돌려준다.
  Future<({bool started, String? reason})> start(WatchTier tier);

  Future<void> setTier(WatchTier tier);

  /// 새 측정을 한 번 청한다 (이슈 #233). 감시 중이 아니면 아무 일도 없다.
  ///
  /// 움직이지 않는 사용자는 distanceFilter 에 막혀 측정이 오지 않는다 — 장소가
  /// 바뀐 순간에는 지금 위치가 필요하다.
  Future<void> requestFix(String reason);

  Future<void> stop();
}

/// Swift `AdaptiveLocationWatcher` 와 맺은 채널 구현
///
/// **어떤 호출도 예외를 올리지 않는다.** 적응형 감시를 못 켜도 영역 감시는
/// 그대로 돈다 — 알림이 약해지는 일이지 앱이 멈출 일이 아니다.
class IosWatchChannel implements IosWatchPlatform {
  const IosWatchChannel();

  static const _channel = MethodChannel(ChannelNames.iosWatch);

  @override
  Future<void> attach(
    Future<void> Function(PositionSample sample) onFix,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLocation') return null;
      try {
        final args = call.arguments as Map;
        await onFix(
          PositionSample(
            latitude: (args['latitude'] as num).toDouble(),
            longitude: (args['longitude'] as num).toDouble(),
            accuracyMeters: (args['accuracyMeters'] as num).toDouble(),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (args['timestampMs'] as num).toInt(),
              isUtc: true,
            ),
          ),
        );
      } on Object catch (error) {
        // 측정 하나가 깨져도 다음 측정은 받아야 한다
        Diagnostics.log('watch', 'ios fix handling failed error=$error');
      }
      return null;
    });
    try {
      final status = await _channel.invokeMapMethod<String, Object?>('attach');
      Diagnostics.log(
        'watch',
        'ios watch attached running=${status?['running']} '
            'wanted=${status?['wanted']} tier=${status?['tier']} '
            'auth=${status?['authorization']}',
      );
    } on Object catch (error) {
      Diagnostics.log('watch', 'ios watch attach failed error=$error');
    }
  }

  @override
  Future<({bool started, String? reason})> start(WatchTier tier) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('start', {
        'tier': tier.name,
      });
      return (
        started: result?['started'] == true,
        reason: result?['reason'] as String?,
      );
    } on Object catch (error) {
      return (started: false, reason: 'channel_error $error');
    }
  }

  @override
  Future<void> setTier(WatchTier tier) =>
      _invoke('setTier', {'tier': tier.name});

  @override
  Future<void> requestFix(String reason) =>
      _invoke('requestFix', {'reason': reason});

  @override
  Future<void> stop() => _invoke('stop');

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object catch (error) {
      Diagnostics.log('watch', 'ios watch $method failed error=$error');
    }
  }
}
