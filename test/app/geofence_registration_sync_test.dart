import 'dart:async';

import 'package:ear_loc_alert/app/background/alert_watch_service.dart';
import 'package:ear_loc_alert/app/geofence_registration_sync.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_monitor.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
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

  @override
  Future<void> startWatching() async => watching = true;

  @override
  Future<void> stopWatching() async => watching = false;

  @override
  Future<void> stopNativeAlert() async => stopAlertCount++;
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
