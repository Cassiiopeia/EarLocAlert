import 'package:ear_loc_alert/app/background/background_alert_port.dart';
import 'package:ear_loc_alert/app/background/geofence_background_processor.dart';
import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluator.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정밀 측정 판정 (이슈 #93)
///
/// 근접 반경 안에서 감시 서비스가 위치를 직접 받을 때 쓰는 경로다.
/// OS 전이 판정과 **같은 도메인 규칙**을 따르는지가 이 테스트의 목적이다 —
/// 두 경로가 갈라지면 한쪽에서만 울리거나 두 번 울린다.
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

  // 중심에서 약 10m — 반경 100m 안
  final inside = PositionSample(
    latitude: 37.56639,
    longitude: 126.9779,
    accuracyMeters: 10,
    timestamp: DateTime.utc(2026, 8, 14, 12),
  );

  // 중심에서 약 1km — 이탈 경계(120m) 밖
  final outside = PositionSample(
    latitude: 37.5753,
    longitude: 126.9779,
    accuracyMeters: 10,
    timestamp: DateTime.utc(2026, 8, 14, 12),
  );

  test('outside 상태에서 반경 안 측정이면 진입 알림을 만든다', () async {
    final f = _fixture(
      places: [place],
      initialStates: {'place-1': GeofenceState.outside},
    );

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNotNull);
    expect(alert!.placeId, 'place-1');
    expect(alert.placeName, '독서실');
    expect(alert.direction, AlertDirection.enter);
    expect(f.states.states['place-1'], GeofenceState.inside);
  });

  test('unknown 에서의 첫 측정은 알림을 만들지 않는다 (규칙 3)', () async {
    final f = _fixture(places: [place]);

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
    // 상태는 확정된다 — 다음 이탈부터 정상 판정된다
    expect(f.states.states['place-1'], GeofenceState.inside);
  });

  test('같은 상태가 유지되면 알림이 없다 (규칙 4)', () async {
    final f = _fixture(
      places: [place],
      initialStates: {'place-1': GeofenceState.inside},
    );

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
    expect(f.events.recorded, isEmpty);
  });

  test('정확도가 반경보다 나쁘면 상태를 바꾸지 않는다 (규칙 2)', () async {
    final f = _fixture(
      places: [place],
      initialStates: {'place-1': GeofenceState.outside},
    );
    final blurry = PositionSample(
      latitude: inside.latitude,
      longitude: inside.longitude,
      accuracyMeters: 300, // 반경 100 보다 나쁘다
      timestamp: inside.timestamp,
    );

    final alert = await f.processor.handlePosition(sample: blurry);

    expect(alert, isNull);
    expect(f.states.states['place-1'], GeofenceState.outside);
  });

  test('inside 에서 반경 밖 측정이면 이탈 알림을 만든다', () async {
    final f = _fixture(
      places: [place],
      initialStates: {'place-1': GeofenceState.inside},
    );

    final alert = await f.processor.handlePosition(sample: outside);

    expect(alert, isNotNull);
    expect(alert!.direction, AlertDirection.exit);
    expect(f.states.states['place-1'], GeofenceState.outside);
  });

  test('비활성 장소는 판정에서 제외된다 — 상태도 건드리지 않는다', () async {
    final f = _fixture(
      places: [place.copyWith(enabled: false)],
      initialStates: {'place-1': GeofenceState.outside},
    );

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
    expect(f.states.states['place-1'], GeofenceState.outside);
  });

  test('진입 전용 장소는 이탈에 알림하지 않지만 이력은 남는다', () async {
    final f = _fixture(
      places: [place.copyWith(direction: AlertDirection.enter)],
      initialStates: {'place-1': GeofenceState.inside},
    );

    final alert = await f.processor.handlePosition(sample: outside);

    expect(alert, isNull);
    // 전이는 사실이고 알림은 설정이다 (docs/03-DOMAIN.md)
    expect(f.events.recorded, hasLength(1));
    expect(f.events.recorded.single.notified, isFalse);
  });

  test('이력에 측정 정확도가 그대로 담긴다 — OS 이벤트의 -1 센티널과 구분된다', () async {
    final f = _fixture(
      places: [place],
      initialStates: {'place-1': GeofenceState.outside},
    );

    await f.processor.handlePosition(sample: inside);

    expect(f.events.recorded.single.accuracyMeters, 10);
  });

  test('여러 장소가 동시에 전이해도 알림은 하나만 돌려준다', () async {
    // 진동과 화면은 하나뿐이다. 나머지 장소의 상태·이력은 정상 기록되어야 한다.
    final second = place.copyWith(id: 'place-2', name: '카페');
    final f = _fixture(
      places: [place, second],
      initialStates: {
        'place-1': GeofenceState.outside,
        'place-2': GeofenceState.outside,
      },
    );

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNotNull);
    expect(alert!.placeId, 'place-1', reason: '목록 순서가 결정적이어야 한다');
    expect(f.states.states['place-2'], GeofenceState.inside);
    expect(f.events.recorded, hasLength(2));
  });

  test('스케줄 창 밖이면 알림하지 않는다', () async {
    // 로컬 시각 기준으로 판정한다 (이슈 #81)
    final scheduled = place.copyWith(
      schedules: const [
        AlertSchedule(
          daysOfWeek: {DateTime.monday},
          startMinuteOfDay: 8 * 60,
          endMinuteOfDay: 9 * 60,
        ),
      ],
    );
    final f = _fixture(
      places: [scheduled],
      initialStates: {'place-1': GeofenceState.outside},
      // 2026-08-14 는 금요일 — 창 밖이다
      now: DateTime(2026, 8, 14, 12),
    );

    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
    expect(f.events.recorded.single.notified, isFalse);
  });
}

({
  GeofenceBackgroundProcessor processor,
  _FakeStateRepository states,
  _FakeEventRepository events,
  _FakeAlertPort alertPort,
})
_fixture({
  required List<AlertPlace> places,
  Map<String, GeofenceState> initialStates = const {},
  DateTime? now,
}) {
  final stateRepo = _FakeStateRepository()..states.addAll(initialStates);
  final eventRepo = _FakeEventRepository();
  final alertPort = _FakeAlertPort();

  return (
    processor: GeofenceBackgroundProcessor(
      places: _FakePlaceRepository(places),
      states: stateRepo,
      events: eventRepo,
      evaluator: const GeofenceEvaluator(),
      alertPort: alertPort,
      idGenerator: () => 'event-1',
      clock: () => now ?? DateTime.utc(2026, 8, 14, 12),
    ),
    states: stateRepo,
    events: eventRepo,
    alertPort: alertPort,
  );
}

class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository(List<AlertPlace> initial)
    : items = {for (final p in initial) p.id: p};

  final Map<String, AlertPlace> items;

  @override
  Future<AlertPlace?> findById(String id) async => items[id];

  @override
  Future<List<AlertPlace>> findAll() async => items.values.toList();

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
  final List<PendingAlert> notified = [];

  @override
  Future<void> notify(PendingAlert alert) async => notified.add(alert);
}
