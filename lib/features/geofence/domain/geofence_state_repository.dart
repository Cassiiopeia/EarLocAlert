import 'geofence_state.dart';

/// 장소별 지오펜스 현재 상태 저장소 (docs/03-DOMAIN.md)
///
/// **이 저장소가 영속적이어야 하는 이유**가 이 앱에서 가장 미묘한 부분이다.
///
/// 알림은 `outside → inside` 전이에서만 발생한다. 상태를 메모리에만 두면
/// 재부팅 후 전부 `unknown` 이 되고, `unknown → inside` 는 알림을 만들지
/// 않으므로 **첫 진입 알림을 통째로 놓친다.**
abstract interface class GeofenceStateRepository {
  /// 저장된 상태. 없으면 `unknown`
  Future<GeofenceState> stateOf(String placeId);

  /// 전체 상태를 한 번에 (백그라운드 판정 루프용)
  Future<Map<String, GeofenceState>> allStates();

  Future<void> updateState(String placeId, GeofenceState state);

  /// 장소가 삭제되면 상태도 함께 지운다
  Future<void> remove(String placeId);
}
