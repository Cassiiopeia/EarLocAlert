/// 네이티브(Kotlin)와 맺은 MethodChannel 이름.
///
/// **이 값은 Kotlin 쪽 문자열과 글자 그대로 같아야 한다.** 한쪽만 바꾸면 호출이
/// 조용히 실패한다. 채널 이름을 새로 만들 때는 여기에 더한다.
abstract final class ChannelNames {
  static const _prefix = 'kr.suhsaechan.ear_loc_alert';

  static const appConfig = '$_prefix/app_config';

  /// 알림 화면 띄우기 — 앱 쪽과 지오펜스 모니터가 같은 채널을 쓴다
  static const alertWindow = '$_prefix/alert_window';
  static const watchEngine = '$_prefix/watch_engine';
  static const systemVolume = '$_prefix/system_volume';
  static const mapsApiKey = '$_prefix/maps_api_key';
  static const currentLocation = '$_prefix/current_location';
  static const alertReliability = '$_prefix/alert_reliability';

  /// iOS 적응형 백그라운드 감시 (이슈 #231) — Swift `AdaptiveLocationWatcher`
  static const iosWatch = '$_prefix/ios_watch';

  /// iOS 백그라운드 세션의 시스템 진동 (이슈 #235) — Swift `SystemVibration`
  static const systemVibration = '$_prefix/system_vibration';

  /// iOS 26+ 잠금 화면 무음 알람 (이슈 #235) — Swift `ArrivalAlarm`
  static const arrivalAlarm = '$_prefix/arrival_alarm';

  /// iOS 알림 설정 읽기 (이슈 #237) — Swift `NotificationSettingsReader`
  static const notificationSettings = '$_prefix/notification_settings';
}
