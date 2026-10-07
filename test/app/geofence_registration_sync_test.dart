import 'dart:async';

import 'package:ear_loc_alert/app/background/alert_watch_service.dart';
import 'package:ear_loc_alert/app/geofence_registration_sync.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_monitor.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 장소 목록 ↔ OS 등록 동기화 (이슈 #63)
void main() {
  AlertPlace place(String id, {bool enabled = true, int minute = 0}) =>
      AlertPlace(
        id: id,
        name: '장소 $id',
        latitude: 37.5,
        longitude: 127.0,
        radiusMeters: 100,
        direction: AlertDirection.both,
        enabled: enabled,
        createdAt: DateTime.utc(2026, 8, 1, 0, minute),
      );

  late _FakePlaceRepository places;
  late _FakeMonitor monitor;
  late _FakeStateRepository states;
  late GeofenceRegistrationSync sync;

  setUp(() {
    places = _FakePlaceRepository();
    monitor = _FakeMonitor();
    states = _FakeStateRepository();
    sync = GeofenceRegistrationSync(
      places: places,
      monitor: monitor,
      states: states,
    );
  });

  tearDown(() => sync.stop());

  test('시작 시 현재 목록으로 동기화한다 — 활성만', () async {
    places.items = [place('a'), place('b', enabled: false), place('c')];

    await sync.start();

    expect(monitor.lastSynced.map((t) => t.placeId), ['a', 'c']);
  });

  test('20개 상한 — 먼저 등록한 장소가 살아남는다 (iOS OS 제한)', () async {
    places.items = [for (var i = 0; i < 25; i++) place('p$i', minute: i)];

    await sync.start();

    expect(monitor.lastSynced, hasLength(20));
    expect(monitor.lastSynced.first.placeId, 'p0');
    expect(monitor.lastSynced.last.placeId, 'p19');
  });

  test('감시에서 빠진 장소는 지오펜스 상태를 unknown 으로 리셋한다', () async {
    // 이전에 등록·판정된 장소가 비활성화된 상황
    monitor.registered = ['a', 'b'];
    states.states['b'] = GeofenceState.outside;
    places.items = [place('a'), place('b', enabled: false)];

    await sync.start();

    // 남겨두면 재활성화 때 outside + initialTrigger(ENTER)가 만나
    // 그 자리에서 가짜 진입 알림이 터진다
    expect(states.states.containsKey('b'), isFalse);
    expect(monitor.lastSynced.map((t) => t.placeId), ['a']);
  });

  test('목록 변경 스트림에 반응한다', () async {
    places.items = [place('a')];
    await sync.start();

    places.items = [place('a'), place('b', minute: 1)];
    places.controller.add(places.items);
    await Future<void>.delayed(Duration.zero);

    expect(monitor.lastSynced.map((t) => t.placeId), ['a', 'b']);
  });

  test('중복 start 는 구독을 한 번만 만든다', () async {
    places.items = [place('a')];

    await sync.start();
    await sync.start();

    expect(places.listenCount, 1);
  });

  test('동기화가 끝날 때마다 알린다 — 홈 상태가 다시 읽는다 (이슈 #142 QA)', () async {
    var synced = 0;
    await sync.stop();
    sync = GeofenceRegistrationSync(
      places: places,
      monitor: monitor,
      states: states,
      onSynced: () => synced++,
    );
    places.items = [];
    await sync.start();
    expect(synced, 1);

    // 첫 장소 등록 — 이 신호가 없으면 홈은 감시=false 를 계속 들고 있었다
    places.items = [place('a')];
    places.controller.add(places.items);
    await Future<void>.delayed(Duration.zero);

    expect(synced, 2);
  });

  group('등록 순간 상태 초기값 (이슈 #231)', () {
    // 장소는 (37.5, 127.0) 반경 100m — 위도 0.01° ≈ 1.1km
    PositionSample fixAt(double latitude, {double accuracy = 15}) =>
        PositionSample(
          latitude: latitude,
          longitude: 127.0,
          accuracyMeters: accuracy,
          timestamp: DateTime.utc(2026, 10, 8),
        );

    late List<PositionSample?> fixes;
    late int fixCalls;

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() {
      fixes = [];
      fixCalls = 0;
      sync = GeofenceRegistrationSync(
        places: places,
        monitor: monitor,
        states: states,
        currentFix: () async {
          fixCalls++;
          return fixes.isEmpty ? null : fixes.removeAt(0);
        },
      );
    });

    test('밖에서 등록하면 outside 로 정한다 — 첫 도착이 알림이 된다', () async {
      fixes = [fixAt(37.51)];
      places.items = [place('a')];

      await sync.start();
      await settle();

      // 예전에는 unknown 으로 남아 iOS 의 첫 영역 이벤트를 기다렸고,
      // 그것이 유실되면 첫 도착이 unknown → inside 로 조용히 지나갔다
      expect(states.states['a'], GeofenceState.outside);
    });

    test('안에서 등록하면 inside — 즉시 알림은 없다', () async {
      fixes = [fixAt(37.5)];
      places.items = [place('a')];

      await sync.start();
      await settle();

      expect(states.states['a'], GeofenceState.inside);
    });

    test('정확도가 나쁘면 unknown 그대로 둔다', () async {
      fixes = [fixAt(37.51, accuracy: 900)];
      places.items = [place('a')];

      await sync.start();
      await settle();

      expect(states.states.containsKey('a'), isFalse);
    });

    test('이미 판정된 장소는 다시 정하지 않는다', () async {
      states.states['a'] = GeofenceState.inside;
      fixes = [fixAt(37.51)];
      places.items = [place('a')];

      await sync.start();
      await settle();

      expect(states.states['a'], GeofenceState.inside);
      expect(fixCalls, 0);
    });

    test('위치를 옮기면 옛 상태를 버리고 새 자리 기준으로 다시 정한다', () async {
      fixes = [fixAt(37.5)];
      places.items = [place('a')];
      await sync.start();
      await settle();
      expect(states.states['a'], GeofenceState.inside);

      // 옛 자리 안에 서서 장소를 1km 북쪽으로 옮겼다 — 옛 inside 가 남으면
      // 새 자리의 첫 도착이 "이미 안"으로 걸러진다
      fixes = [fixAt(37.5)];
      final moved = place('a').copyWith(latitude: 37.51);
      places.items = [moved];
      places.controller.add(places.items);
      await settle();

      expect(states.states['a'], GeofenceState.outside);
    });

    test('위치를 재는 사이 실제 판정이 먼저 정하면 덮지 않는다', () async {
      final pending = Completer<PositionSample?>();
      sync = GeofenceRegistrationSync(
        places: places,
        monitor: monitor,
        states: states,
        currentFix: () => pending.future,
      );
      places.items = [place('a')];
      await sync.start();

      // OS 영역 이벤트가 먼저 inside 를 정했다
      states.states['a'] = GeofenceState.inside;
      pending.complete(fixAt(37.51));
      await settle();

      expect(states.states['a'], GeofenceState.inside);
    });

    test('바뀌지 않은 장소의 상태는 다른 장소 변경에 휩쓸리지 않는다', () async {
      fixes = [fixAt(37.51)];
      places.items = [place('a')];
      await sync.start();
      await settle();
      states.states['a'] = GeofenceState.inside;

      fixes = [fixAt(37.51)];
      places.items = [place('a'), place('b', minute: 1)];
      places.controller.add(places.items);
      await settle();

      expect(states.states['a'], GeofenceState.inside);
      expect(states.states['b'], GeofenceState.outside);
    });
  });

  group('상시 감시 서비스 (이슈 #74)', () {
    late _FakeWatchService watch;

    setUp(() {
      watch = _FakeWatchService();
      sync = GeofenceRegistrationSync(
        places: places,
        monitor: monitor,
        states: states,
        watch: watch,
      );
    });

    test('감시할 장소가 있으면 서비스를 켠다', () async {
      places.items = [place('a')];

      await sync.start();

      expect(watch.watching, isTrue);
    });

    test('감시할 장소가 하나도 없으면 켜지 않는다', () async {
      places.items = [];

      await sync.start();

      expect(
        watch.watching,
        isFalse,
        reason: '알릴 것이 없는데 상시 알림을 띄우면 배터리만 먹는 앱이다',
      );
    });

    test('비활성 장소만 있으면 켜지 않는다', () async {
      places.items = [place('a', enabled: false)];

      await sync.start();

      expect(watch.watching, isFalse);
    });

    test('마지막 장소가 빠지면 서비스를 끈다', () async {
      places.items = [place('a')];
      await sync.start();
      expect(watch.watching, isTrue);

      places.items = [];
      places.controller.add(places.items);
      await Future<void>.delayed(Duration.zero);

      expect(watch.watching, isFalse);
    });

    test('장소가 다시 생기면 서비스를 켠다', () async {
      places.items = [];
      await sync.start();

      places.items = [place('a')];
      places.controller.add(places.items);
      await Future<void>.delayed(Duration.zero);

      expect(watch.watching, isTrue);
    });

    test('감시 중지는 서비스도 끈다', () async {
      places.items = [place('a')];
      await sync.start();

      await sync.stop();

      expect(watch.watching, isFalse);
    });
  });
}

class _FakeWatchService implements AlertWatchService {
  bool watching = false;
  int stopAlertCount = 0;

  /// 마지막으로 위임받은 지오펜스 페이로드 (이슈 #93)
  List<Map<String, Object?>>? syncedGeofences;

  @override
  Future<void> startWatching() async => watching = true;

  @override
  Future<void> stopWatching() async => watching = false;

  @override
  Future<void> stopNativeAlert() async => stopAlertCount++;

  @override
  Future<bool> isAlerting() async => false;

  @override
  Future<void> syncGeofences(List<Map<String, Object?>> geofences) async =>
      syncedGeofences = geofences;
}

class _FakePlaceRepository implements PlaceRepository {
  List<AlertPlace> items = [];
  final controller = StreamController<List<AlertPlace>>.broadcast();
  int listenCount = 0;

  @override
  Future<List<AlertPlace>> findAll() async => List.of(items);

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      items.where((p) => p.enabled).toList();

  @override
  Future<AlertPlace?> findById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> save(AlertPlace place) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => items.length;

  @override
  Stream<List<AlertPlace>> watchAll() {
    listenCount++;
    return controller.stream;
  }
}

class _FakeMonitor implements GeofenceMonitor {
  List<GeofenceTarget> lastSynced = [];
  List<String> registered = [];

  @override
  Future<void> sync(List<GeofenceTarget> targets) async {
    lastSynced = targets;
    registered = targets.map((t) => t.placeId).toList();
  }

  @override
  Future<void> stopAll() async => registered = [];

  @override
  Future<List<String>> registeredPlaceIds() async => List.of(registered);
}

class _FakeStateRepository implements GeofenceStateRepository {
  final Map<String, GeofenceState> states = {};

  @override
  Future<GeofenceState> stateOf(String placeId) async =>
      states[placeId] ?? GeofenceState.unknown;

  @override
  Future<Map<String, GeofenceState>> allStates() async => Map.of(states);

  @override
  Future<void> updateState(String placeId, GeofenceState state) async =>
      states[placeId] = state;

  @override
  Future<void> remove(String placeId) async => states.remove(placeId);
}
