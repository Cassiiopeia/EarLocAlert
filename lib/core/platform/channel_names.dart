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
}
