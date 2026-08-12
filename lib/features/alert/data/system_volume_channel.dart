import 'package:flutter/services.dart';

import '../domain/alert_effects.dart';

/// [SystemVolumeService] 의 네이티브 채널 구현 (이슈 #86)
///
/// Android 만 응답한다. iOS 는 시스템 볼륨을 바꾸는 공개 API 가 없어
/// 채널 자체가 없고(MissingPluginException), 여기서 삼켜져 조용히
/// 지나간다 — 앱 재생 볼륨만으로 동작한다.
///
/// 볼륨 원복에 필요한 "올리기 전 값"은 네이티브가 들고 있다.
/// Dart 쪽에 두면 백그라운드 승격·프로세스 재시작 사이에서 유실된다.
class SystemVolumeChannel implements SystemVolumeService {
  const SystemVolumeChannel();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/system_volume',
  );

  @override
  Future<void> raiseTo(double fraction) =>
      _invoke('raiseSystemVolume', {'fraction': fraction.clamp(0.0, 1.0)});

  @override
  Future<void> restore() => _invoke('restoreSystemVolume', null);

  Future<void> _invoke(String method, Map<String, Object?>? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Object {
      // iOS(채널 없음)와 Android 의 방해금지 제한(SecurityException) 모두
      // 정상 경로다 — 볼륨을 못 올려도 재생과 진동은 계속된다.
    }
  }
}
