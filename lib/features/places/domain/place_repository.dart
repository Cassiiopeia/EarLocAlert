import 'alert_place.dart';

/// 장소 저장소 (docs/02-ARCHITECTURE.md 규칙 3)
///
/// 화면은 이 인터페이스만 본다. 구현이 Drift 인지 아닌지 알지 못하며,
/// 테스트에서는 가짜 구현을 넣는다.
abstract interface class PlaceRepository {
  /// 등록된 모든 장소 (생성 시각 오름차순)
  Future<List<AlertPlace>> findAll();

  /// 감시 대상만 — `enabled == true`
  Future<List<AlertPlace>> findEnabled();

  Future<AlertPlace?> findById(String id);

  /// 등록 또는 수정. `id` 는 호출자가 미리 생성해 넘긴다
  Future<void> save(AlertPlace place);

  Future<void> delete(String id);

  /// 활성/비활성 토글 (F1.7)
  Future<void> setEnabled(String id, {required bool enabled});

  /// 등록 개수 — iOS 20개 제한 확인에 쓴다 (docs/05-PLATFORM.md)
  Future<int> count();

  /// 목록 변경 스트림. 화면이 구독한다
  Stream<List<AlertPlace>> watchAll();
}
