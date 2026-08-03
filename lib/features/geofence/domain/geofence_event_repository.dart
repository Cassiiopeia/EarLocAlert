import 'geofence_event.dart';

/// 진입/이탈 이력 저장소 (docs/03-DOMAIN.md)
///
/// F7(이력 화면)은 Phase 2 지만 기록은 MVP 부터 남긴다.
/// 이 저장소가 없으면 "안 울렸다"는 문제를 조사할 방법이 전혀 없다.
abstract interface class GeofenceEventRepository {
  Future<void> record(GeofenceEvent event);

  /// 최근 이력 (발생 시각 내림차순)
  Future<List<GeofenceEvent>> findRecent({int limit = 100});

  /// 특정 장소의 이력
  Future<List<GeofenceEvent>> findByPlace(String placeId, {int limit = 100});

  /// 보관 기간이 지난 기록 삭제 (docs/03-DOMAIN.md — 90일)
  ///
  /// 기기 저장소를 계속 잠식하면 안 되고, 90일 전 진입 기록이
  /// 필요한 사용자는 없다. 앱 시작 시 1회 호출한다.
  ///
  /// 삭제된 행 수를 반환한다.
  Future<int> deleteOlderThan(DateTime cutoffUtc);
}
