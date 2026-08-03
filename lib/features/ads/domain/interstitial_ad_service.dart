/// 전면광고 제어 (docs/02-ARCHITECTURE.md 규칙 3)
///
/// 화면과 조율 계층은 이 인터페이스만 본다. `google_mobile_ads` 를 직접
/// 부르지 않으므로, **광고가 해제를 막지 않는다**는 규칙을 실기기 없이
/// 테스트할 수 있다.
abstract interface class InterstitialAdService {
  /// 광고를 미리 불러온다.
  ///
  /// 알림이 발화하는 시점에 호출하면 사용자가 해제할 때쯤 준비가 끝나 있다.
  /// **실패해도 아무 일도 일어나지 않아야 한다** — 이 메서드는 예외를
  /// 던지지 않는다.
  Future<void> preload();

  /// 준비된 광고가 있는가
  bool get isReady;

  /// 광고를 보여준다.
  ///
  /// 준비되지 않았으면 아무것도 하지 않고 `false` 를 반환한다.
  /// **기다리지 않는다** — 호출 시점에 없으면 그냥 넘어간다.
  Future<bool> showIfReady();

  Future<void> dispose();
}
