/// 후기 창 판정 결과: 띄움 또는 사유 (#296)
enum ReviewPromptDecision {
  request('request'),
  tooFewDismissals('too_few_dismissals'),
  tooSoonSinceFirstUse('too_soon_since_first_use'),
  requestedRecently('requested_recently');

  const ReviewPromptDecision(this.logToken);

  /// 진단 로그용 고정 영문 토큰
  final String logToken;
}

/// 스토어 인앱 후기 창을 띄울지 판단 (#296)
/// 조건 3개: 알림 정상 해제 3회 이상, 첫 사용 후 3일 이상, 마지막 요청 후 120일 이상
abstract final class ReviewPromptPolicy {
  /// 알림을 실제로 써 본 기준 (해제 횟수)
  static const int minimumAlertDismissals = 3;

  /// 첫 사용 후 기다릴 기간
  static const Duration minimumSinceFirstUse = Duration(days: 3);

  /// 다시 요청하기까지의 간격 — 스토어 자체 상한보다 보수적으로
  static const Duration minimumBetweenRequests = Duration(days: 120);

  static ReviewPromptDecision decide({
    required int alertDismissCount,
    required DateTime firstUsedAt,
    required DateTime? lastRequestedAt,
    required DateTime now,
  }) {
    if (alertDismissCount < minimumAlertDismissals) {
      return ReviewPromptDecision.tooFewDismissals;
    }
    if (now.difference(firstUsedAt) < minimumSinceFirstUse) {
      return ReviewPromptDecision.tooSoonSinceFirstUse;
    }
    final lastRequest = lastRequestedAt;
    if (lastRequest != null &&
        now.difference(lastRequest) < minimumBetweenRequests) {
      return ReviewPromptDecision.requestedRecently;
    }
    return ReviewPromptDecision.request;
  }
}
