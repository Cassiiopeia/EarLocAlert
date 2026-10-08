/// 알림에 다는 버튼의 식별자 (이슈 #237)
///
/// 알림을 내는 쪽(앱 세션·백그라운드)과 버튼 눌림을 받는 쪽이 같은 문자열을 써야
/// 한다. alert feature 와 app 계층이 함께 보므로 core 에 둔다 (규칙 1).
abstract final class NotificationActions {
  /// 도착·이탈 알림의 iOS 카테고리 — "알림 끄기" 버튼이 붙는다
  static const arrivalCategory = 'ear_loc_alert_arrival';

  /// "알림 끄기" 버튼. 앱을 띄우지 않고 그 자리에서 끈다
  static const dismiss = 'dismiss_alert';
}
