import 'package:ear_loc_alert/app/background/background_alert_port.dart';
import 'package:ear_loc_alert/app/background/geofence_background_processor.dart';
import 'package:ear_loc_alert/app/background/ios_adaptive_watch.dart';
import 'package:ear_loc_alert/app/background/ios_watch_channel.dart';
import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/app/background/region_event_relay.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluator.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/geofence/domain/watch_tier.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iOS 적응형 감시의 Dart 쪽 (이슈 #231)
///
/// 네이티브는 단계를 적용하고 측정을 넘길 뿐이다. 단계 전환·판정 연결·중복
/// 차단은 여기서 실기기 없이 확인한다.
void main() {
  // 반경 300m → 근접 원 900m
  final place = AlertPlace(
    id: '01a11647-test',
    name: 'te',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 300,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  var minute = 0;
  PositionSample fix(double latitude, {double accuracy = 10}) => PositionSample(
    latitude: latitude,
    longitude: 127.0,
    accuracyMeters: accuracy,
    // 위치 튐 판정에 걸리지 않게 측정 간격을 둔다
    timestamp: DateTime.utc(2026, 10, 8, 12, minute++),
  );

  late _RecordingLogger logger;
  late _FakePlatform platform;
  late _FakeStates states;
  late _FakeAlertPort port;
  late _FakePlaces places;
  late IosAdaptiveWatch watch;

  setUp(() {
    minute = 0;
    Diagnostics.resetForTest();
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    platform = _FakePlatform();
    states = _FakeStates();
    port = _FakeAlertPort();
    places = _FakePlaces([place]);
    watch = IosAdaptiveWatch(
      platform: platform,
      processor: GeofenceBackgroundProcessor(
        places: places,
        states: states,
        events: _FakeEvents(),
        evaluator: const GeofenceEvaluator(),
        alertPort: port,
        idGenerator: () => 'e',
        clock: () => DateTime.utc(2026, 10, 8, 12),
      ),
      places: places,
      alertPort: port,
    );
  });

  tearDown(Diagnostics.resetForTest);

  test('멀어지고 다가옴에 따라 단계를 바꾸고 네이티브에 알린다', () async {
    await watch.onFix(fix(37.6)); // ≈11km — 먼
    await watch.onFix(fix(37.52)); // ≈2.2km, 근접 원까지 ≈1.3km — 중간
    await watch.onFix(fix(37.505)); // ≈556m — 근접 원 안, 정밀

    expect(platform.tiers, [WatchTier.far, WatchTier.mid, WatchTier.precise]);
    expect(
      logger.lines.where((l) => l.contains('[watch] tier changed')),
      hasLength(3),
    );
    expect(
      logger.lines.last,
      isNot(contains('tier changed')),
      reason: '정밀 측정은 판정 요약 한 줄을 남긴다',
    );
  });

  test('밖으로 정해진 장소에 들어가면 도착 알림을 낸다 — 첫 도착이 사라지지 않는다', () async {
    // 등록 순간 outside 로 정해졌다 (시드)
    states.states[place.id] = GeofenceState.outside;

    await watch.onFix(fix(37.505)); // 근접 원 안, 반경 밖
    await watch.onFix(fix(37.5005)); // ≈56m — 반경 안

    expect(port.notified.single.placeId, place.id);
    expect(port.notified.single.direction, AlertDirection.enter);
    expect(states.states[place.id], GeofenceState.inside);
  });

  test('근접 원 밖 측정은 판정하지 않는다 — 상태를 건드리지 않는다', () async {
    await watch.onFix(fix(37.6));

    expect(states.states, isEmpty);
    expect(port.notified, isEmpty);
  });

  test('영역 이벤트와 정밀 측정이 같은 도착을 보면 한 번만 울린다', () async {
    states.states[place.id] = GeofenceState.outside;

    // 같은 판정기·같은 상태 저장소 — 먼저 온 쪽이 inside 로 바꾸면
    // 뒤엣것은 inside → inside 라 무알림이다
    await Future.wait([
      watch.onFix(fix(37.5005)),
      watch.handleRegionEvent(
        const RegionEvent(placeId: '01a11647-test', entered: true),
      ),
    ]);

    expect(port.notified, hasLength(1));
  });

  test('장소가 없어지면 감시를 멈추고 사유를 남긴다', () async {
    await watch.stopWatching();

    expect(platform.stopped, isTrue);
    expect(logger.lines.last, contains('ios watch stopped reason=no_places'));
  });

  test('"항상" 권한이 없으면 시작하지 못한 사유를 남긴다', () async {
    platform.startResult = (started: false, reason: 'not_always');

    await watch.startWatching();

    expect(logger.lines.last, contains('reason=not_always'));
  });

  group('장소가 바뀌면 단계를 다시 고른다 (이슈 #233)', () {
    test('사용자 옆으로 옮긴 장소는 움직이지 않아도 곧바로 정밀이 된다', () async {
      await watch.onFix(fix(37.52)); // 근접 원까지 ≈1.3km — 중간
      expect(watch.tier, WatchTier.mid);

      // 실기기 재현: 반경 50m(근접 원 500m)로 사용자 바로 옆에 옮겼다
      places.items[0] = place.copyWith(latitude: 37.5201, radiusMeters: 50);
      await watch.startWatching();

      expect(watch.tier, WatchTier.precise);
      expect(platform.tiers.last, WatchTier.precise);
      expect(
        logger.lines.where((l) => l.contains('tier changed tier=precise')),
        [contains('reason=places_changed')],
      );
      expect(platform.fixRequests, [
        'places_changed',
      ], reason: '옛 측정만 믿지 않고 지금 위치를 한 번 더 청한다');
    });

    test('옛 측정으로는 판정하지 않는다 — 단계만 바꾼다', () async {
      states.states[place.id] = GeofenceState.outside;
      await watch.onFix(fix(37.52));

      // 장소를 마지막 측정 자리로 옮겨도 그 측정으로 도착을 울리지 않는다
      places.items[0] = place.copyWith(latitude: 37.52);
      await watch.startWatching();

      expect(port.notified, isEmpty);
      expect(states.states[place.id], GeofenceState.outside);
    });

    test('측정이 아직 없으면 사유를 남기고 새 측정만 청한다', () async {
      await watch.startWatching();

      expect(platform.tiers, isEmpty);
      expect(
        logger.lines,
        contains(contains('tier reevaluation skipped reason=no_last_fix')),
      );
      expect(platform.fixRequests, ['places_changed']);
    });

    test('감시를 시작하지 못했으면 다시 고르지 않는다', () async {
      await watch.onFix(fix(37.52));
      platform.startResult = (started: false, reason: 'not_always');

      await watch.startWatching();

      expect(platform.fixRequests, isEmpty);
    });

    test('옛 측정 시각으로 정밀 체류를 재지 않는다 — 곧바로 상한에 걸리지 않는다', () async {
      final now = DateTime.utc(2026, 10, 8, 18);
      final timed = IosAdaptiveWatch(
        platform: platform,
        processor: GeofenceBackgroundProcessor(
          places: places,
          states: states,
          events: _FakeEvents(),
          evaluator: const GeofenceEvaluator(),
          alertPort: port,
          idGenerator: () => 'e',
          clock: () => now,
        ),
        places: places,
        alertPort: port,
        clock: () => now,
      );
      // 여섯 시간 전 측정이 마지막이다
      await timed.onFix(
        PositionSample(
          latitude: 37.52,
          longitude: 127.0,
          accuracyMeters: 10,
          timestamp: now.subtract(const Duration(hours: 6)),
        ),
      );
      places.items[0] = place.copyWith(latitude: 37.5201, radiusMeters: 50);
      await timed.startWatching();
      expect(timed.tier, WatchTier.precise);

      // 청한 새 측정이 도착한다 — 여전히 근접 원 안이면 정밀이 유지돼야 한다
      await timed.onFix(
        PositionSample(
          latitude: 37.52,
          longitude: 127.0,
          accuracyMeters: 10,
          timestamp: now.add(const Duration(seconds: 5)),
        ),
      );
      expect(timed.tier, WatchTier.precise);
      expect(logger.lines, isNot(contains(contains('reason=precise_cap'))));
    });
  });

  group('AppIsolateAlertPort', () {
    final alert = PendingAlert(
      placeId: 'p',
      placeName: 'te',
      direction: AlertDirection.enter,
      soundEnabled: false,
      occurredAt: DateTime.utc(2026, 10, 8),
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('화면이 떠 있으면 OS 알림 없이 대기 알림만 저장하고 승격을 부른다', () async {
      final background = _FakeAlertPort();
      var promoted = 0;
      final appPort = AppIsolateAlertPort(
        background: background,
        store: PendingAlertStore(),
        isForeground: () => true,
        onForegroundAlert: () => promoted++,
      );

      await appPort.notify(alert);

      expect(background.notified, isEmpty);
      expect(promoted, 1);
      expect(await PendingAlertStore().hasPending(), isTrue);
    });

    test('화면이 없으면 백그라운드 알림으로 보낸다 — 직전에 플러그인을 준비한다', () async {
      final background = _FakeAlertPort();
      var readied = 0;
      final appPort = AppIsolateAlertPort(
        background: background,
        store: PendingAlertStore(),
        isForeground: () => false,
        onForegroundAlert: () => fail('승격하면 안 된다'),
        ensureBackgroundReady: () async => readied++,
      );

      await appPort.notify(alert);

      expect(readied, 1);
      expect(background.notified.single.placeName, 'te');
    });

    test('화면이 없으면 알림을 낸 뒤 앱 세션 시작을 부른다 (이슈 #233)', () async {
      final order = <String>[];
      final background = _FakeAlertPort(onNotify: () => order.add('notify'));
      final appPort = AppIsolateAlertPort(
        background: background,
        store: PendingAlertStore(),
        isForeground: () => false,
        onForegroundAlert: () => fail('승격하면 안 된다'),
        onBackgroundAlert: (a) => order.add('session ${a.placeName}'),
      );

      await appPort.notify(alert);

      expect(order, ['notify', 'session te']);
    });

    test('알림 발행이 실패해도 앱 세션은 시작한다', () async {
      var started = 0;
      final appPort = AppIsolateAlertPort(
        background: _FakeAlertPort(onNotify: () => throw StateError('post')),
        store: PendingAlertStore(),
        isForeground: () => false,
        onForegroundAlert: () => fail('승격하면 안 된다'),
        onBackgroundAlert: (_) => started++,
      );

      await expectLater(appPort.notify(alert), throwsStateError);
      expect(started, 1);
    });

    test('화면이 떠 있으면 앱 세션 시작을 따로 부르지 않는다 — 승격이 한다', () async {
      final appPort = AppIsolateAlertPort(
        background: _FakeAlertPort(),
        store: PendingAlertStore(),
        isForeground: () => true,
        onForegroundAlert: () {},
        onBackgroundAlert: (_) => fail('두 번째 세션이 된다'),
      );

      await appPort.notify(alert);
    });
  });
}

class _FakePlatform implements IosWatchPlatform {
  final List<WatchTier> tiers = [];
  bool stopped = false;
  ({bool started, String? reason}) startResult = (started: true, reason: null);

  @override
  Future<void> attach(Future<void> Function(PositionSample) onFix) async {}

  @override
  Future<({bool started, String? reason})> start(WatchTier tier) async =>
      startResult;

  @override
  Future<void> setTier(WatchTier tier) async => tiers.add(tier);

  final List<String> fixRequests = [];

  @override
  Future<void> requestFix(String reason) async => fixRequests.add(reason);

  @override
  Future<void> stop() async => stopped = true;
}

class _RecordingLogger implements DiagnosticLogger {
  final List<String> lines = [];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}

class _FakePlaces implements PlaceRepository {
  _FakePlaces(this.items);

  final List<AlertPlace> items;

  @override
  Future<AlertPlace?> findById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<AlertPlace>> findAll() async => List.of(items);

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      items.where((p) => p.enabled).toList();

  @override
  Future<void> save(AlertPlace place) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => items.length;

  @override
  Stream<List<AlertPlace>> watchAll() => const Stream.empty();
}

class _FakeStates implements GeofenceStateRepository {
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

class _FakeEvents implements GeofenceEventRepository {
  @override
  Future<void> record(GeofenceEvent event) async {}

  @override
  Future<List<GeofenceEvent>> findRecent({int limit = 100}) async => [];

  @override
  Future<List<GeofenceEvent>> findByPlace(
    String placeId, {
    int limit = 100,
  }) async => [];

  @override
  Future<int> deleteOlderThan(DateTime cutoffUtc) async => 0;
}

class _FakeAlertPort implements BackgroundAlertPort {
  _FakeAlertPort({this.onNotify});

  final void Function()? onNotify;
  final List<PendingAlert> notified = [];

  @override
  Future<void> notify(PendingAlert alert) async {
    onNotify?.call();
    notified.add(alert);
  }
}
