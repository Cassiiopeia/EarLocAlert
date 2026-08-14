import 'package:ear_loc_alert/app/background/alert_decision.dart';
import 'package:ear_loc_alert/app/background/background_alert_port.dart';
import 'package:ear_loc_alert/app/background/geofence_background_processor.dart';
import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/app/background/watch_engine_host.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluator.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 감시 서비스 엔진의 Dart 진입점 (이슈 #93)
///
/// 네이티브 없이 전 흐름을 검증한다 — 이것이 이 앱 아키텍처의 목적이다.
void main() {
  final place = AlertPlace(
    id: 'place-1',
    name: '독서실',
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  group('정밀 측정 경로', () {
    test('진입이면 알림 결정을 돌려주고 PendingAlert 를 저장한다', () async {
      final f = _fixture(
        places: [place],
        states: {'place-1': GeofenceState.outside},
      );

      final decision = await f.host.onPosition(
        latitude: 37.56639,
        longitude: 126.9779,
        accuracyMeters: 10,
        timestampUtc: DateTime.utc(2026, 8, 14, 12),
      );

      expect(decision.shouldAlert, isTrue);
      expect(decision.placeId, 'place-1');
      expect(decision.placeName, '독서실');
      expect(decision.direction, 'enter');
      expect(decision.soundEnabled, isTrue);

      // 화면 승격 후 AlertController 가 이어받는 경로가 살아있어야 한다
      expect(f.store.saved, isNotNull);
      expect(f.store.saved!.placeId, 'place-1');
    });

    test('알림이 필요없으면 shouldAlert 가 false 이고 저장하지 않는다', () async {
      final f = _fixture(
        places: [place],
        states: {'place-1': GeofenceState.inside},
      );

      final decision = await f.host.onPosition(
        latitude: 37.56639,
        longitude: 126.9779,
        accuracyMeters: 10,
        timestampUtc: DateTime.utc(2026, 8, 14, 12),
      );

      expect(decision.shouldAlert, isFalse);
      expect(f.store.saved, isNull);
    });

    test('소리 설정이 결정에 실려 나간다', () async {
      final f = _fixture(
        places: [place.copyWith(soundEnabled: false)],
        states: {'place-1': GeofenceState.outside},
      );

      final decision = await f.host.onPosition(
        latitude: 37.56639,
        longitude: 126.9779,
        accuracyMeters: 10,
        timestampUtc: DateTime.utc(2026, 8, 14, 12),
      );

      expect(decision.soundEnabled, isFalse);
    });
  });

  group('OS 전이 폴백 경로', () {
    test('같은 결정 형태를 돌려준다', () async {
      final f = _fixture(
        places: [place],
        states: {'place-1': GeofenceState.outside},
      );

      final decision = await f.host.onOsTransition(
        placeId: 'place-1',
        entered: true,
      );

      expect(decision.shouldAlert, isTrue);
      expect(decision.direction, 'enter');
      expect(f.store.saved, isNotNull);
    });

    test('이탈도 판정된다', () async {
      final f = _fixture(
        places: [place],
        states: {'place-1': GeofenceState.inside},
      );

      final decision = await f.host.onOsTransition(
        placeId: 'place-1',
        entered: false,
      );

      expect(decision.shouldAlert, isTrue);
      expect(decision.direction, 'exit');
    });

    test('정밀 경로가 이미 판정한 전이는 두 번 울리지 않는다', () async {
      // 두 경로가 같은 상태 저장소를 보므로 중복이 구조적으로 막힌다
      final f = _fixture(
        places: [place],
        states: {'place-1': GeofenceState.outside},
      );

      final first = await f.host.onPosition(
        latitude: 37.56639,
        longitude: 126.9779,
        accuracyMeters: 10,
        timestampUtc: DateTime.utc(2026, 8, 14, 12),
      );
      final second = await f.host.onOsTransition(
        placeId: 'place-1',
        entered: true,
      );

      expect(first.shouldAlert, isTrue);
      expect(second.shouldAlert, isFalse, reason: '이미 inside 라 전이가 없다');
    });

    test('삭제된 장소의 늦은 이벤트는 조용히 넘어간다', () async {
      final f = _fixture(places: [], states: {'ghost': GeofenceState.outside});

      final decision = await f.host.onOsTransition(
        placeId: 'ghost',
        entered: true,
      );

      expect(decision.shouldAlert, isFalse);
    });
  });

  test('판정 중 예외가 나도 던지지 않고 알림 없음으로 떨어진다', () async {
    // 백그라운드 크래시는 사용자에게 보이지 않은 채 감시만 죽인다
    final f = _fixture(
      places: [place],
      states: {'place-1': GeofenceState.outside},
      throwOnRead: true,
    );

    final decision = await f.host.onPosition(
      latitude: 37.56639,
      longitude: 126.9779,
      accuracyMeters: 10,
      timestampUtc: DateTime.utc(2026, 8, 14, 12),
    );

    expect(decision.shouldAlert, isFalse);
  });

  test('저장이 실패해도 알림 없음으로 떨어진다 — 예외가 새지 않는다', () async {
    final f = _fixture(
      places: [place],
      states: {'place-1': GeofenceState.outside},
      throwOnSave: true,
    );

    final decision = await f.host.onPosition(
      latitude: 37.56639,
      longitude: 126.9779,
      accuracyMeters: 10,
      timestampUtc: DateTime.utc(2026, 8, 14, 12),
    );

    expect(decision.shouldAlert, isFalse);
  });

  test('toMap 은 네이티브가 읽는 키를 담는다', () {
    const decision = AlertDecision(
      shouldAlert: true,
      placeId: 'p',
      placeName: '집',
      direction: 'exit',
      soundEnabled: false,
    );

    expect(decision.toMap(), {
      'shouldAlert': true,
      'placeId': 'p',
      'placeName': '집',
      'direction': 'exit',
      'soundEnabled': false,
    });
  });

  test('알림 없음의 toMap 도 모든 키를 담는다 — Kotlin 이 null 로 읽는다', () {
    expect(AlertDecision.none.toMap(), {
      'shouldAlert': false,
      'placeId': null,
      'placeName': null,
      'direction': null,
      'soundEnabled': true,
    });
  });
}

({WatchEngineHost host, _FakePendingAlertStore store}) _fixture({
  required List<AlertPlace> places,
  Map<String, GeofenceState> states = const {},
  bool throwOnRead = false,
  bool throwOnSave = false,
}) {
  final store = _FakePendingAlertStore(throwOnSave: throwOnSave);
  return (
    host: WatchEngineHost(
      processor: GeofenceBackgroundProcessor(
        places: _FakePlaceRepository(places, throwOnRead: throwOnRead),
        states: _FakeStateRepository()..states.addAll(states),
        events: _FakeEventRepository(),
        evaluator: const GeofenceEvaluator(),
        alertPort: _FakeAlertPort(),
        idGenerator: () => 'event-1',
        clock: () => DateTime.utc(2026, 8, 14, 12),
      ),
      store: store,
    ),
    store: store,
  );
}

/// `save` 만 가로챈다 — 나머지는 실제 구현이 필요 없다
class _FakePendingAlertStore extends PendingAlertStore {
  _FakePendingAlertStore({this.throwOnSave = false});

  final bool throwOnSave;
  PendingAlert? saved;

  @override
  Future<void> save(PendingAlert alert) async {
    if (throwOnSave) throw StateError('저장 실패');
    saved = alert;
  }
}

class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository(List<AlertPlace> initial, {this.throwOnRead = false})
    : items = {for (final p in initial) p.id: p};

  final Map<String, AlertPlace> items;
  final bool throwOnRead;

  @override
  Future<AlertPlace?> findById(String id) async {
    if (throwOnRead) throw StateError('DB 읽기 실패');
    return items[id];
  }

  @override
  Future<List<AlertPlace>> findAll() async {
    if (throwOnRead) throw StateError('DB 읽기 실패');
    return items.values.toList();
  }

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      items.values.where((p) => p.enabled).toList();

  @override
  Future<void> save(AlertPlace place) async => items[place.id] = place;

  @override
  Future<void> delete(String id) async => items.remove(id);

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => items.length;

  @override
  Stream<List<AlertPlace>> watchAll() => const Stream.empty();
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

class _FakeEventRepository implements GeofenceEventRepository {
  final List<GeofenceEvent> recorded = [];

  @override
  Future<void> record(GeofenceEvent event) async => recorded.add(event);

  @override
  Future<List<GeofenceEvent>> findRecent({int limit = 100}) async => recorded;

  @override
  Future<List<GeofenceEvent>> findByPlace(
    String placeId, {
    int limit = 100,
  }) async => recorded.where((e) => e.placeId == placeId).toList();

  @override
  Future<int> deleteOlderThan(DateTime cutoffUtc) async => 0;
}

class _FakeAlertPort implements BackgroundAlertPort {
  @override
  Future<void> notify(PendingAlert alert) async {}
}
