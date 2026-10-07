import 'dart:async';

import '../core/diagnostics/diagnostics.dart';
import '../core/diagnostics/log_format.dart';
import '../features/geofence/domain/geofence_monitor.dart';
import '../features/geofence/domain/geofence_state.dart';
import '../features/geofence/domain/geofence_state_repository.dart';
import '../features/geofence/domain/geofence_target.dart';
import '../features/geofence/domain/position_sample.dart';
import '../features/geofence/domain/state_seeding.dart';
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
    this.onSynced,
    Future<PositionSample?> Function()? currentFix,
  }) : _places = places,
       _monitor = monitor,
       _states = states,
       _watch = watch,
       _currentFix = currentFix;

  final PlaceRepository _places;
  final GeofenceMonitor _monitor;
  final GeofenceStateRepository _states;

  /// 상시 감시 서비스 (이슈 #74) — 감시 대상이 있을 때만 켠다
  final AlertWatchService _watch;

  /// iOS 는 앱당 20개가 OS 제한이다 (docs/05-PLATFORM.md).
  /// 등록 화면이 상한을 막지만, 여기서도 자르는 것이 마지막 방어선이다.
  final int maxTargets;

  /// 동기화가 끝날 때마다 부른다 — 등록 결과를 보여주는 쪽(홈 상태)이
  /// 다시 읽게 한다 (이슈 #142 QA)
  final void Function()? onSynced;

  StreamSubscription<List<AlertPlace>>? _subscription;

  /// 등록 순간 안팎을 정할 현재 위치 1회 조회 (이슈 #231). null 이면
  /// 초기값을 정하지 않는다 — 예전처럼 OS 의 첫 이벤트를 기다린다.
  final Future<PositionSample?> Function()? _currentFix;

  /// 직전 동기화의 장소별 위치·반경 (이슈 #231).
  ///
  /// **위치나 반경이 바뀐 장소의 옛 상태는 의미가 없다.** 옛 자리 기준
  /// `inside` 가 남으면 새 자리의 첫 도착이 "이미 안"으로 걸러진다.
  Map<String, _Geometry> _geometry = const {};

  /// 감시를 시작한다 — 현재 목록으로 1회 동기화 후 변경을 구독한다.
  Future<void> start() async {
    if (_subscription != null) return;
    await _apply(await _places.findAll());
    _subscription = _places.watchAll().listen(
      (places) => unawaited(_applySafely(places)),
    );
  }

  /// 등록을 지금 목록으로 다시 밀어 넣는다 (이슈 #164).
  ///
  /// 앱 언어를 바꾼 직후에 부른다 — 감시 서비스가 다시 시작 요청을 받아 상시
  /// 알림 문구와 알림 채널 이름을 **바뀐 언어로 다시 만들게** 하려는 것이다.
  /// 감시 대상이 없으면 서비스를 띄우지 않는다(`_apply` 가 판단한다).
  Future<void> refresh() async => _applySafely(await _places.findAll());

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
      Diagnostics.log('sync', 'geofence sync failed $error');
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

    // 초기값을 정할 장소를 고른다 (이슈 #231) — 새로 들어왔거나(unknown),
    // 위치·반경이 바뀐 장소. 이미 판정된 장소는 건드리지 않는다
    final previous = _geometry;
    _geometry = {for (final t in targets) t.placeId: _Geometry.of(t)};
    final toSeed = <GeofenceTarget>[];
    for (final target in targets) {
      final before = previous[target.placeId];
      final moved = before != null && before != _Geometry.of(target);
      if (moved) {
        await _states.remove(target.placeId);
        Diagnostics.log(
          'sync',
          'state reset place=${shortId(target.placeId)} '
              'reason=geometry_changed',
        );
      }
      if (moved ||
          await _states.stateOf(target.placeId) == GeofenceState.unknown) {
        toSeed.add(target);
      }
    }
    // 위치 조회는 수 초 걸릴 수 있다 — 등록 반영을 기다리게 하지 않는다
    if (toSeed.isNotEmpty && _currentFix != null) {
      unawaited(_seedSafely(toSeed));
    }

    // 등록 개수가 0 이면 어떤 도착도 감지되지 않는다 — 알림이 안 오는
    // 상황에서 가장 먼저 확인해야 할 값이다 (이슈 #95)
    Diagnostics.log(
      'sync',
      'geofence sync done registered=${targets.length} '
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

    // 등록 결과가 바뀌었을 수 있다 — 홈 상태가 옛 값을 들고 있으면
    // 첫 장소를 등록하자마자 "감시 꺼짐" 이 뜬다
    onSynced?.call();
  }

  Future<void> _seedSafely(List<GeofenceTarget> targets) async {
    try {
      await _seed(targets);
    } on Object catch (error) {
      // 초기값을 못 정해도 감시는 돈다 — 예전처럼 OS 이벤트를 기다릴 뿐이다
      Diagnostics.log('sync', 'state seed failed error=$error');
    }
  }

  /// 현재 위치로 안팎을 정해 상태 저장소에 쓴다 (이슈 #231).
  ///
  /// **안이면 알림을 내지 않는다** — 지금 설계 그대로다. 등록한 자리에서
  /// 바로 울리면 사용자는 고장으로 본다. 나갔다 다시 들어올 때 울린다.
  Future<void> _seed(List<GeofenceTarget> targets) async {
    final fix = await _currentFix!();
    for (final target in targets) {
      final id = shortId(target.placeId);
      // 위치를 재는 사이 장소가 또 바뀌었다 — 옛 위치·반경으로 계산한
      // 값을 쓰면 안 된다. 새 동기화가 다시 정한다
      if (_geometry[target.placeId] != _Geometry.of(target)) {
        Diagnostics.log(
          'sync',
          'state seed skipped place=$id reason=superseded',
        );
        continue;
      }

      final decision = decideSeedState(target: target, fix: fix);
      final distance = meters(decision.distanceMeters);
      final accuracy = meters(fix?.accuracyMeters);
      final state = decision.state;
      if (state == null) {
        Diagnostics.log(
          'sync',
          'state seed skipped place=$id reason=${decision.skip!.label} '
              'distance=$distance acc=$accuracy',
        );
        continue;
      }

      // 위치를 재는 사이 실제 판정(OS 이벤트·정밀 측정)이 먼저 정했다 —
      // 그쪽이 더 최신이다
      if (await _states.stateOf(target.placeId) != GeofenceState.unknown) {
        Diagnostics.log(
          'sync',
          'state seed skipped place=$id reason=already_known',
        );
        continue;
      }

      await _states.updateState(target.placeId, state);
      Diagnostics.log(
        'sync',
        'state seeded place=$id state=${state.name} '
            'distance=$distance acc=$accuracy'
            '${state == GeofenceState.inside ? " note=already_inside_no_alert" : ""}',
      );
    }
  }
}

/// 상태가 유효한 기준 — 위치와 반경 (이슈 #231)
class _Geometry {
  const _Geometry(this.latitude, this.longitude, this.radiusMeters);

  factory _Geometry.of(GeofenceTarget target) =>
      _Geometry(target.latitude, target.longitude, target.radiusMeters);

  final double latitude;
  final double longitude;
  final int radiusMeters;

  @override
  bool operator ==(Object other) =>
      other is _Geometry &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, radiusMeters);
}
