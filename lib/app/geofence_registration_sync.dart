import 'dart:async';

import '../core/diagnostics/diagnostics.dart';
import '../features/geofence/domain/geofence_monitor.dart';
import '../features/geofence/domain/geofence_state_repository.dart';
import '../features/geofence/domain/geofence_target.dart';
import '../features/places/domain/alert_place.dart';
import '../features/places/domain/place_repository.dart';
import 'background/alert_watch_service.dart';

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
    AlertWatchService watch = const NoopAlertWatchService(),
    this.maxTargets = 20,
  }) : _places = places,
       _monitor = monitor,
       _states = states,
       _watch = watch;

  final PlaceRepository _places;
  final GeofenceMonitor _monitor;
  final GeofenceStateRepository _states;

  /// 상시 감시 서비스 (이슈 #74) — 감시 대상이 있을 때만 켠다
  final AlertWatchService _watch;

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
    // 감시를 멈추면 상시 알림도 사라져야 한다 — 아무것도 지켜보지 않는데
    // 알림 줄에 남아 있으면 사용자는 앱이 뭘 하는지 알 수 없다
    await _watch.stopWatching();
  }

  Future<void> _applySafely(List<AlertPlace> places) async {
    try {
      await _apply(places);
    } on Object catch (error) {
      // 동기화 실패가 화면을 죽이면 안 된다. 다음 목록 변경 때 재시도된다.
      // 다만 **기록은 남긴다** — 등록이 조용히 실패하면 도착을 영영
      // 감지하지 못하는데, 예전에는 그 사실조차 알 수 없었다 (이슈 #95)
      Diagnostics.log('sync', '지오펜스 동기화 실패 $error');
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
            // OS 등록 여부는 스케줄과 무관하다 — 창 밖에도 등록을 유지해야
            // 상태 추적이 끊기지 않는다 (이슈 #81). 값만 실어 보낸다.
            schedules: p.schedules,
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

    // 등록 개수가 0 이면 어떤 도착도 감지되지 않는다 — 알림이 안 오는
    // 상황에서 가장 먼저 확인해야 할 값이다 (이슈 #95)
    Diagnostics.log(
      'sync',
      '지오펜스 동기화 완료 등록=${targets.length}건 '
          'ids=${targets.map((t) => t.placeId).join(",")}',
    );

    // 상시 감시 서비스는 **지켜볼 것이 있을 때만** 띄운다 (이슈 #74).
    // 등록이 끝난 뒤에 켜는 이유는, 서비스가 뜨자마자 대기 중인 알림을
    // 확인하는데 그 시점에 등록이 비어 있으면 안 되기 때문이다.
    if (targets.isEmpty) {
      await _watch.stopWatching();
    } else {
      await _watch.startWatching();
    }
  }
}
