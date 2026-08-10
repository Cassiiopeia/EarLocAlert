import 'dart:async';

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
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 백그라운드 지오펜스 이벤트 조율 (이슈 #63)
///
/// 플랫폼 없이 전체 흐름을 검증한다 — 이것이 이 앱 아키텍처의 목적이다
/// (docs/02-ARCHITECTURE.md).
void main() {
  final basePlace = AlertPlace(
    id: 'place-1',
    name: '독서실',
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  late _FakePlaceRepository places;
  late _FakeStateRepository states;
  late _FakeEventRepository events;
  late _FakeAlertPort alertPort;
  late GeofenceBackgroundProcessor processor;

  /// [now] 를 주면 그 시각으로 고정한다.
  ///
  /// 스케줄 판정은 `clock().toLocal()` 을 쓰므로, 시간대에 의존하지 않으려면
  /// **로컬 `DateTime`** 을 넘겨야 한다(로컬 값의 `toLocal()` 은 자기 자신이다).
  /// 기본값이 UTC 인 것은 스케줄이 없는 기존 테스트에는 영향이 없기
  /// 때문이다 — 창이 비면 시각과 무관하게 항상 활성이다 (이슈 #81).
  GeofenceBackgroundProcessor build({DateTime? now}) =>
      GeofenceBackgroundProcessor(
        places: places,
        states: states,
        events: events,
        evaluator: const GeofenceEvaluator(),
        alertPort: alertPort,
        idGenerator: () => 'event-1',
        clock: () => now ?? DateTime.utc(2026, 8, 4, 12),
      );

  setUp(() {
    places = _FakePlaceRepository([basePlace]);
    states = _FakeStateRepository();
    events = _FakeEventRepository();
    alertPort = _FakeAlertPort();
    processor = build();
  });

  group('전이와 알림', () {
    test('outside → ENTER: 상태 갱신·이력 기록·알림 발행', () async {
      states.states['place-1'] = GeofenceState.outside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
        latitude: 37.5664,
        longitude: 126.9780,
      );

      expect(states.states['place-1'], GeofenceState.inside);
      expect(events.recorded, hasLength(1));
      expect(events.recorded.single.type, GeofenceEventType.entered);
      expect(events.recorded.single.notified, isTrue);
      // 이벤트 좌표는 기기 좌표를 우선한다
      expect(events.recorded.single.latitude, 37.5664);
      expect(alertPort.notified, hasLength(1));
      expect(alertPort.notified.single.placeName, '독서실');
      expect(alertPort.notified.single.direction, AlertDirection.enter);
    });

    test('inside → EXIT: 이탈 알림', () async {
      states.states['place-1'] = GeofenceState.inside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.exited,
      );

      expect(states.states['place-1'], GeofenceState.outside);
      expect(alertPort.notified.single.direction, AlertDirection.exit);
      // 기기 좌표가 없으면 장소 중심 좌표로 대체된다
      expect(events.recorded.single.latitude, basePlace.latitude);
      // OS 이벤트에는 정확도가 없다 — 센티널 -1
      expect(events.recorded.single.accuracyMeters, -1);
    });

    test('unknown → ENTER (등록 직후): 상태만 잡고 알림·이력 없음', () async {
      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(states.states['place-1'], GeofenceState.inside);
      expect(events.recorded, isEmpty);
      expect(alertPort.notified, isEmpty);
    });

    test('inside → ENTER 반복 (iOS 재부팅 중복): 무시', () async {
      states.states['place-1'] = GeofenceState.inside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(events.recorded, isEmpty);
      expect(alertPort.notified, isEmpty);
    });
  });

  group('알림 여부 규칙 (docs/03-DOMAIN.md)', () {
    test('진입 전용 장소의 이탈 — 이력은 남고 알림은 없다', () async {
      places.items['place-1'] = basePlace.copyWith(
        direction: AlertDirection.enter,
      );
      states.states['place-1'] = GeofenceState.inside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.exited,
      );

      expect(events.recorded.single.notified, isFalse);
      expect(alertPort.notified, isEmpty);
    });

    test('비활성 장소 — 이력은 남고 알림은 없다', () async {
      places.items['place-1'] = basePlace.copyWith(enabled: false);
      states.states['place-1'] = GeofenceState.outside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(events.recorded.single.notified, isFalse);
      expect(alertPort.notified, isEmpty);
    });
  });

  group('알림 시간대 (이슈 #81)', () {
    // 평일 08:00 ~ 10:00. 2026-08-10 은 월요일이다.
    const weekdayMorning = AlertSchedule(
      daysOfWeek: {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      },
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
    );

    setUp(() {
      places.items['place-1'] = basePlace.copyWith(
        schedules: const [weekdayMorning],
      );
    });

    test('창 안의 진입 — 평소대로 알림이 나간다', () async {
      states.states['place-1'] = GeofenceState.outside;
      processor = build(now: DateTime(2026, 8, 10, 9, 10)); // 월 09:10 (로컬)

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(states.states['place-1'], GeofenceState.inside);
      expect(events.recorded.single.notified, isTrue);
      expect(alertPort.notified, hasLength(1));
    });

    // ── 회귀 가드 ──────────────────────────────────────────────
    // 이 설계의 전제는 **"창 밖에서도 상태 추적은 끊기지 않는다"** 이다.
    // 누군가 "창 밖이면 일찍 return 하자"고 최적화하면 ① 이 깨지고,
    // 그러면 창이 열린 뒤에도 상태가 unknown/outside 로 어긋나 첫 진입을
    // 영영 놓친다. 세 가지를 한 테스트에서 함께 본다.
    test('창 밖의 진입 — 상태는 저장되고, 이력은 남고, 알림만 없다', () async {
      states.states['place-1'] = GeofenceState.outside;
      processor = build(now: DateTime(2026, 8, 10, 7, 50)); // 월 07:50 (로컬)

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      // ① 상태 추적은 끊기지 않는다 — 가장 중요하다
      expect(states.states['place-1'], GeofenceState.inside);
      // ② 조사 수단이 남는다
      expect(events.recorded, hasLength(1));
      expect(events.recorded.single.notified, isFalse);
      // ③ 알림만 나가지 않는다
      expect(alertPort.notified, isEmpty);
    });

    test('창 밖에서 들어와 있다가 창 안에서 나가면 이탈 알림이 정상 발생한다', () async {
      // 07:50 진입 (창 밖 — 조용히 상태만 inside 로)
      states.states['place-1'] = GeofenceState.outside;
      processor = build(now: DateTime(2026, 8, 10, 7, 50));
      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );
      expect(alertPort.notified, isEmpty);

      // 08:30 이탈 (창 안) — 앞서 상태가 inside 로 남아 있어야 전이가 잡힌다
      processor = build(now: DateTime(2026, 8, 10, 8, 30));
      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.exited,
      );

      expect(states.states['place-1'], GeofenceState.outside);
      expect(alertPort.notified, hasLength(1));
      expect(alertPort.notified.single.direction, AlertDirection.exit);
    });

    test('요일이 다르면 알림이 없다', () async {
      states.states['place-1'] = GeofenceState.outside;
      processor = build(now: DateTime(2026, 8, 15, 9)); // 토 09:00

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(events.recorded.single.notified, isFalse);
      expect(alertPort.notified, isEmpty);
    });
  });

  group('경계 상황', () {
    test('삭제된 장소의 이벤트 — 상태를 정리하고 조용히 끝낸다', () async {
      states.states['ghost'] = GeofenceState.inside;

      await processor.handle(
        placeId: 'ghost',
        eventType: GeofenceEventType.exited,
      );

      expect(states.states.containsKey('ghost'), isFalse);
      expect(events.recorded, isEmpty);
      expect(alertPort.notified, isEmpty);
    });

    test('소리 설정이 PendingAlert 로 전달된다', () async {
      places.items['place-1'] = basePlace.copyWith(soundEnabled: false);
      states.states['place-1'] = GeofenceState.outside;

      await processor.handle(
        placeId: 'place-1',
        eventType: GeofenceEventType.entered,
      );

      expect(alertPort.notified.single.soundEnabled, isFalse);
    });
  });
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
