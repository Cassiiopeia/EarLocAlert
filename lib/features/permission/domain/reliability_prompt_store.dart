/// 알림 신뢰성 권한을 이미 한 번 권했는지 (이슈 #74)
///
/// 이 권한들은 **선택**이다. 거절한 사용자에게 앱을 켤 때마다 같은 화면을
/// 보이면 온보딩이 아니라 통행세가 된다. 한 번 권한 사실만 남긴다.
///
/// 도메인 데이터가 아니라 단일 설정값이라 SharedPreferences 를 쓴다
/// (docs/02-ARCHITECTURE.md 저장소 표).
abstract interface class ReliabilityPromptStore {
  Future<bool> wasSeen();

  Future<void> markSeen();

  /// 다시 권할 수 있게 되돌린다.
  ///
  /// 사용자가 홈에서 "눌러서 강화"로 직접 찾아온 경우다 — 그때는 스스로
  /// 요청한 것이므로 한 번 거절했다는 기록이 길을 막으면 안 된다.
  Future<void> reset();
}

/// 저장하지 않는 구현 — 테스트·플랫폼 미지원 경로용
class InMemoryReliabilityPromptStore implements ReliabilityPromptStore {
  bool _seen = false;

  @override
  Future<bool> wasSeen() async => _seen;

  @override
  Future<void> markSeen() async => _seen = true;

  @override
  Future<void> reset() async => _seen = false;
}
