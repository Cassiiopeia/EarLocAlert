/// 진동 시험의 마지막 답 (이슈 #237)
///
/// **iOS 는 시스템 진동 설정을 앱에 알려주지 않는다.** 손쉬운 사용의 진동이나
/// 햅틱을 꺼 두면 도착해도 아무 느낌이 없는데, 앱은 그것을 모른 채 "감시 중"이라고
/// 말한다. 그래서 사용자에게 직접 떨어 보고 느꼈는지 묻는다 — 그 답이 유일한 단서다.
class VibrationCheckResult {
  const VibrationCheckResult({required this.felt, required this.answeredAt});

  /// 진동이 느껴졌다고 답했는가
  final bool felt;

  /// 답한 시각 (UTC). 언제 확인했는지 알아야 오래된 답을 가린다
  final DateTime answeredAt;
}

/// 진동 시험 답 저장소 (이슈 #237)
abstract interface class VibrationCheckStore {
  /// 마지막 답. 시험한 적이 없으면 null
  Future<VibrationCheckResult?> last();

  Future<void> save(VibrationCheckResult result);
}
