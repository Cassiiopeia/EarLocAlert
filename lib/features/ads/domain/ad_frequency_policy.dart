/// 전면광고 노출 빈도 제어 (docs/07-MONETIZATION.md)
///
/// 이 로직이 조용히 깨지면 AdMob 정책 위반 → 계정 정지로 간다.
/// 정지되면 다른 앱의 수익까지 끊기고 되돌릴 방법이 마땅치 않다.
/// 그래서 순수 함수로 두고 단위 테스트로 강제한다 (docs/04-CONVENTIONS.md).
class AdFrequencyPolicy {
  const AdFrequencyPolicy({
    this.minInterval = const Duration(minutes: 3),
    this.dailyCap = 10,
  });

  /// 전면광고 최소 노출 간격 (F8.3) — 연속 알림 시 중복 노출 차단
  final Duration minInterval;

  /// 1일 노출 상한 (F8.4)
  final int dailyCap;

  /// 지금 전면광고를 노출해도 되는가.
  ///
  /// 어떤 입력에서도 이 판정이 알림 해제를 막지 않는다 — 이 함수는
  /// 해제가 끝난 뒤에만 호출된다 (docs/02-ARCHITECTURE.md 규칙 4).
  bool canShowInterstitial({
    required DateTime now,
    required DateTime? lastShownAt,

    /// 오늘(사용자 로컬 기준 날짜) 노출된 횟수
    required int shownToday,

    /// 앱 최초 실행 — 첫인상을 광고로 만들지 않는다
    required bool isFirstLaunch,
  }) {
    if (isFirstLaunch) return false;
    if (shownToday >= dailyCap) return false;
    if (lastShownAt != null && now.difference(lastShownAt) < minInterval) {
      return false;
    }
    return true;
  }
}
