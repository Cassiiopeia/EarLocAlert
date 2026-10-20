import '../features/geofence/domain/geofence_target.dart';
import '../features/places/domain/alert_place.dart';

/// AlertPlace > GeofenceTarget 매핑 단일 지점 (docs/02-ARCHITECTURE.md 규칙 1)
///
/// geofence 는 places 를 모른다 — app 계층이 판정에 필요한 값만 옮긴다.
extension AlertPlaceGeofenceTarget on AlertPlace {
  GeofenceTarget toGeofenceTarget() => GeofenceTarget(
    placeId: id,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    direction: direction,
    enabled: enabled,
    // OS 등록 여부는 스케줄과 무관하다 — 창 밖에도 등록을 유지해야
    // 상태 추적이 끊기지 않는다 (이슈 #81). 값만 실어 보낸다.
    schedules: schedules,
  );
}
