import 'dart:async';

import '../features/geofence/domain/geofence_monitor.dart';
import '../features/geofence/domain/geofence_state_repository.dart';
import '../features/geofence/domain/geofence_target.dart';
import '../features/places/domain/alert_place.dart';
import '../features/places/domain/place_repository.dart';

/// 장소 목록 ↔ OS 지오펜스 등록 동기화 (이슈 #63)
///
/// places 와 geofence 의 협력은 app 계층이 조율한다
/// (docs/02-ARCHITECTURE.md 규칙 1). 장소가 바뀔 때마다 감시 대상
/// 집합을 다시 계산해 OS 에 반영한다.
class GeofenceRegistrationSync {
  GeofenceRegistrationSync({
    required PlaceRepository places,
    required GeofenceMonitor monitor,
    required GeofenceStateRepository states,
    this.maxTargets = 20,
  }) : _places = places,
       _monitor = monitor,
       _states = states;

  final PlaceRepository _places;
  final GeofenceMonitor _monitor;
  final GeofenceStateRepository _states;

  /// iOS 는 앱당 20개가 OS 제한이다 (docs/05-PLATFORM.md).
  /// 등록 화면이 상한을 막지만, 여기서도 자르는 것이 마지막 방어선이다.
  final int maxTargets;

  StreamSubscription<List<AlertPlace>>? _subscription;

  /// 감시를 시작한다 — 현재 목록으로 1회 동기화 후 변경을 구독한다.
  Future<void> start() async {
    if (_subscription != null) return;
    await _apply(await _places.findAll());
    _subscription = _places.watchAll().listen(
      (places) => unawaited(_applySafely(places)),
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _applySafely(List<AlertPlace> places) async {
    try {
      await _apply(places);
    } on Object {
      // 동기화 실패가 화면을 죽이면 안 된다. 다음 목록 변경 때 재시도된다.
    }
  }

  Future<void> _apply(List<AlertPlace> places) async {
    // findAll 은 생성 시각 오름차순 — 상한 초과 시 먼저 등록한 장소가
    // 살아남는 결정적 규칙이 된다
    final targets = places
        .where((p) => p.enabled)
        .take(maxTargets)
        .map(
          (p) => GeofenceTarget(
            placeId: p.id,
            latitude: p.latitude,
            longitude: p.longitude,
            radiusMeters: p.radiusMeters,
            direction: p.direction,
            enabled: p.enabled,
          ),
        )
        .toList();

    // 감시에서 빠지는 장소는 상태를 unknown 으로 되돌린다 — 남겨두면
    // 재활성화 때 묵은 상태(outside)와 initialTrigger(ENTER)가 만나
    // 그 자리에서 가짜 진입 알림이 터진다 (unknown→inside 는 무알림)
    final targetIds = {for (final t in targets) t.placeId};
    final registered = await _monitor.registeredPlaceIds();
    for (final id in registered) {
      if (!targetIds.contains(id)) {
        await _states.remove(id);
      }
    }

    await _monitor.sync(targets);
  }
}
