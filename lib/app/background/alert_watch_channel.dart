import 'package:flutter/services.dart';

import 'alert_watch_service.dart';

/// [AlertWatchService] 의 네이티브 구현 (이슈 #74)
///
/// **어떤 호출도 예외를 올리지 않는다.** 서비스를 못 띄우는 것은 알림이
/// 약해지는 일이지 앱이 멈출 일이 아니다 — 지오펜스 등록과 포그라운드
/// 알림 세션은 이것 없이도 그대로 동작한다.
class AlertWatchChannel implements AlertWatchService {
  const AlertWatchChannel();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/alert_window',
  );

  @override
  Future<void> startWatching() => _invoke('startWatch');

  @override
  Future<void> stopWatching() => _invoke('stopWatch');

  @override
  Future<void> stopNativeAlert() => _invoke('stopAlert');

  @override
  Future<void> syncGeofences(List<Map<String, Object?>> geofences) =>
      _invoke('syncGeofences', {'geofences': geofences});

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object {
      // iOS 에는 채널 자체가 없다(MissingPluginException). Android 에서도
      // 서비스 승격 실패는 여기로 온다 — 둘 다 정상 경로다.
    }
  }
}
