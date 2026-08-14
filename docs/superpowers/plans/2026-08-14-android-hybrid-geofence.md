# Android 하이브리드 지오펜스 감시 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱을 실행하지 않아도 등록한 장소에 도착하면 즉시 알림이 발화되게 한다.

**Architecture:** 지오펜스 이벤트가 `native_geofence` → WorkManager 를 경유하며 지연·유실되는 것이 원인이다. Android 에서는 앱이 `GeofencingClient` 로 직접 등록하고 앱 소유 리시버가 이벤트를 받아 이미 상시 실행 중인 `AlertWatchService` 로 직행한다. 서비스는 Flutter 엔진을 상시 보유해 이벤트마다 엔진을 새로 띄우지 않는다. 장소마다 지오펜스를 둘 등록해(근접 반경·실제 반경) 정밀 감시가 실패해도 발화를 보장한다.

**Tech Stack:** Flutter 3.35.5 / Dart 3.9, Kotlin, Google Play Services Location (GeofencingClient, FusedLocationProviderClient), Riverpod code generation, Drift, freezed

**관련:** 이슈 #93 · 설계 `docs/superpowers/specs/2026-08-14-android-hybrid-geofence-design.md`

## Global Constraints

- **판정 로직은 Dart 에만 둔다.** `GeofenceEvaluator` 를 Kotlin 으로 포팅하지 않는다 (docs/03-DOMAIN.md 규칙 5)
- **네이티브에서 소리를 내지 않는다.** 서비스는 진동과 화면 띄우기만 한다 (CLAUDE.md 절대규칙 2, 결정 019)
- **feature 끼리 직접 import 하지 않는다.** 협력은 app 계층이 조율한다 (docs/02-ARCHITECTURE.md 규칙 1)
- **백그라운드 진입점에서 `BuildContext` 를 만지지 않는다** (규칙 5)
- **릴리스 로그에 좌표를 남기지 않는다. `print` 금지** (docs/04-CONVENTIONS.md)
- **상태 관리는 `@riverpod` code generation 단독** (docs/04-CONVENTIONS.md)
- **시각 저장은 `DateTime.now().toUtc()`**, 스케줄 판정만 로컬 (결정 021)
- **iOS 는 변경하지 않는다.** `native_geofence` 는 iOS 전용으로 유지
- 코드 주석은 한국어로, WHY 중심으로 작성한다
- Flutter 명령은 `~/development/flutter-3.35.5/bin/flutter` 를 쓴다 (`export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"`)
- 커밋 메시지에 AI 작성 흔적을 넣지 않는다

## 테스트 가능 범위에 대한 정직한 기록

Dart 계층(판정 조율·근접 반경·채널 어댑터)은 플랫폼 없이 전부 테스트한다. **Kotlin 계층은 이 프로젝트에 Android 단위 테스트 인프라가 없어 자동 테스트가 없다** — 실기기 검증(Task 9)으로만 닫힌다. 이 사실을 숨기지 말고, Kotlin 태스크는 "빌드 통과 + 실기기 확인 항목"을 완료 기준으로 삼는다.

## File Structure

**Dart — 신규**

| 파일 | 책임 |
|---|---|
| `lib/features/geofence/domain/proximity_radius.dart` | 근접 반경 계산 (순수 함수) |
| `lib/app/background/watch_engine_host.dart` | 감시 서비스 엔진의 Dart 진입점. 채널 수신 → 판정 위임 → 결과 반환 |
| `lib/app/background/alert_decision.dart` | 판정 결과 DTO (채널 반환값) |
| `lib/features/geofence/data/android_geofence_monitor.dart` | Android `GeofenceMonitor` 구현 (채널 경유) |

**Dart — 수정**

| 파일 | 변경 |
|---|---|
| `lib/app/background/geofence_background_processor.dart` | `handlePosition()` 추가 (정밀 측정 판정) |
| `lib/features/geofence/data/native_geofence_monitor.dart` | iOS 전용으로 축소 (주석·용도 명시) |
| `lib/app/geofence_providers.dart` | 플랫폼별 monitor 분기 |
| `lib/app/background/alert_watch_service.dart` | 인터페이스에 `syncGeofences` 추가 |
| `lib/app/background/alert_watch_channel.dart` | 신규 메서드 구현 |
| `lib/app/geofence_registration_sync.dart` | Android 경로에서 monitor 대신 watch 로 등록 위임 |

**Kotlin — 신규**

| 파일 | 책임 |
|---|---|
| `GeofenceRegistrar.kt` | `GeofencingClient` 등록/해제 |
| `GeofenceReceiver.kt` | 지오펜스 PendingIntent 수신 → 서비스 전달 |
| `BootReceiver.kt` | 재부팅 후 서비스 복구 |
| `WatchEngine.kt` | FlutterEngine 보유·판정 채널 호출 |
| `PreciseLocationTracker.kt` | 정밀 모드 위치 스트림 |

**Kotlin — 수정**: `AlertWatchService.kt`, `MainActivity.kt`, `AndroidManifest.xml`, `build.gradle.kts`

---

### Task 1: 근접 반경 계산

**Files:**
- Create: `lib/features/geofence/domain/proximity_radius.dart`
- Test: `test/features/geofence/proximity_radius_test.dart`

**Interfaces:**
- Consumes: 없음 (순수 함수)
- Produces: `double proximityRadiusMeters(int radiusMeters)` — 근접 지오펜스 반경(미터)

- [ ] **Step 1: 실패하는 테스트를 작성한다**

```dart
import 'package:ear_loc_alert/features/geofence/domain/proximity_radius.dart';
import 'package:flutter_test/flutter_test.dart';

/// 근접 반경 — 정밀 감시로 전환할 바깥 경계 (이슈 #93)
void main() {
  test('작은 반경은 최소값 500m 로 올라간다', () {
    // 100 × 3 = 300 < 500
    expect(proximityRadiusMeters(100), 500);
  });

  test('큰 반경은 3배가 최소값을 넘어 비례한다', () {
    // 500 × 3 = 1500 > 500
    expect(proximityRadiusMeters(500), 1500);
  });

  test('경계값 — 3배가 정확히 최소값이면 최소값이다', () {
    expect(proximityRadiusMeters(500 ~/ 3), 500);
  });

  test('최대 반경 2000m 도 계산된다', () {
    expect(proximityRadiusMeters(2000), 6000);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `export PATH="$HOME/development/flutter-3.35.5/bin:$PATH" && flutter test test/features/geofence/proximity_radius_test.dart`
Expected: FAIL — `proximity_radius.dart` 없음

- [ ] **Step 3: 최소 구현을 작성한다**

```dart
/// 근접 반경 — 정밀 감시를 켤 바깥 경계 (이슈 #93)
///
/// OS 지오펜스는 감지가 수십 초 늦을 수 있다. 실제 반경에서 그것을
/// 기다리면 이미 지나친 뒤다. 그래서 **더 넓은 원을 하나 더 두고**,
/// 거기 들어온 시점부터 앱이 직접 위치를 보며 판정한다.
///
/// 3배로 잡은 이유는 시속 60km(≈17m/s)에서 약 30초의 여유가 나오기
/// 때문이다. 최소 500m 하한을 둔 이유는 작은 반경(50m)에 비례만
/// 적용하면 여유가 150m 밖에 안 되어 전환 즉시 도착해버리기 때문이다.
///
/// **미검증 값이다** — 실기기 실측(S-2·S-3) 후 확정한다.
double proximityRadiusMeters(int radiusMeters) {
  const minimumMeters = 500.0;
  const multiplier = 3.0;
  final proportional = radiusMeters * multiplier;
  return proportional > minimumMeters ? proportional : minimumMeters;
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/features/geofence/proximity_radius_test.dart`
Expected: PASS (4건)

- [ ] **Step 5: 커밋한다**

```bash
git add lib/features/geofence/domain/proximity_radius.dart test/features/geofence/proximity_radius_test.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 정밀 감시로 전환할 근접 반경 계산을 도메인에 추가한다. 반경 3배와 최소 500m 중 큰 값 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 2: 정밀 측정 판정 — `GeofenceBackgroundProcessor.handlePosition()`

**Files:**
- Modify: `lib/app/background/geofence_background_processor.dart`
- Test: `test/app/geofence_background_processor_position_test.dart`

**Interfaces:**
- Consumes: 기존 `GeofenceBackgroundProcessor` 생성자, `GeofenceEvaluator.evaluate()`, `PositionSample`
- Produces: `Future<PendingAlert?> handlePosition({required PositionSample sample})` — 알림이 필요하면 그 `PendingAlert`, 아니면 null

**왜 기존 클래스에 추가하나** — OS 전이 판정(`handle`)과 정밀 측정 판정은 **판정 이후가 완전히 같다** (상태 저장 → 이력 기록 → `shouldNotify` → 알림). 이 뒷부분을 복제하면 두 경로가 반드시 어긋난다. 진입점만 늘린다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

```dart
import 'package:ear_loc_alert/app/background/geofence_background_processor.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:flutter_test/flutter_test.dart';

// 주의: Fake 저장소는 기존 test/app/geofence_background_processor_test.dart 의
// _FakePlaceRepository·_FakeStateRepository·_FakeEventRepository·_FakeAlertPort 와
// 같은 구조다. 그 파일에서 복사해 이 파일 하단에 둔다 (테스트 간 결합을 만들지 않는다).

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

  // 중심에서 약 10m 떨어진 지점 (반경 100m 안)
  final inside = PositionSample(
    latitude: 37.56639,
    longitude: 126.9779,
    accuracyMeters: 10,
    timestamp: DateTime.utc(2026, 8, 14, 12),
  );

  // 중심에서 약 1km 떨어진 지점 (이탈 경계 밖)
  final outside = PositionSample(
    latitude: 37.5753,
    longitude: 126.9779,
    accuracyMeters: 10,
    timestamp: DateTime.utc(2026, 8, 14, 12),
  );

  test('outside 상태에서 반경 안 측정이면 진입 알림을 만든다', () async {
    final f = _fixture(place: place, initialState: GeofenceState.outside);
    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNotNull);
    expect(alert!.placeId, 'place-1');
    expect(alert.direction, AlertDirection.enter);
    expect(await f.states.stateOf('place-1'), GeofenceState.inside);
  });

  test('unknown 에서의 첫 측정은 알림을 만들지 않는다 (규칙 3)', () async {
    final f = _fixture(place: place, initialState: GeofenceState.unknown);
    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
    expect(await f.states.stateOf('place-1'), GeofenceState.inside);
  });

  test('같은 상태가 유지되면 알림이 없다 (규칙 4)', () async {
    final f = _fixture(place: place, initialState: GeofenceState.inside);
    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
  });

  test('정확도가 반경보다 나쁘면 상태를 바꾸지 않는다 (규칙 2)', () async {
    final f = _fixture(place: place, initialState: GeofenceState.outside);
    final blurry = PositionSample(
      latitude: inside.latitude,
      longitude: inside.longitude,
      accuracyMeters: 300, // 반경 100 보다 나쁨
      timestamp: inside.timestamp,
    );

    final alert = await f.processor.handlePosition(sample: blurry);

    expect(alert, isNull);
    expect(await f.states.stateOf('place-1'), GeofenceState.outside);
  });

  test('inside 에서 반경 밖 측정이면 이탈 알림을 만든다', () async {
    final f = _fixture(place: place, initialState: GeofenceState.inside);
    final alert = await f.processor.handlePosition(sample: outside);

    expect(alert, isNotNull);
    expect(alert!.direction, AlertDirection.exit);
  });

  test('비활성 장소는 판정에서 제외된다', () async {
    final f = _fixture(
      place: place.copyWith(enabled: false),
      initialState: GeofenceState.outside,
    );
    final alert = await f.processor.handlePosition(sample: inside);

    expect(alert, isNull);
  });
}
```

`_fixture` 헬퍼와 Fake 저장소는 기존 `test/app/geofence_background_processor_test.dart` 의 것을 이 파일에 복사해 사용한다. `_fixture` 는 `({GeofenceBackgroundProcessor processor, _FakeStateRepository states})` 를 반환한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/app/geofence_background_processor_position_test.dart`
Expected: FAIL — `handlePosition` 메서드 없음

- [ ] **Step 3: `handlePosition()` 을 구현한다**

`lib/app/background/geofence_background_processor.dart` 의 `handle()` 아래에 추가한다. 기존 `handle()` 의 후반부(상태 저장 이후)를 `_recordAndDecide()` 로 추출해 두 경로가 공유하게 만든다.

```dart
  /// 정밀 측정 하나로 모든 활성 장소를 판정한다 (이슈 #93)
  ///
  /// OS 전이 판정([handle])과 달리 좌표가 입력이다. 근접 반경 안에서
  /// 서비스가 위치를 직접 받을 때 쓴다.
  ///
  /// 여러 장소가 동시에 전이할 수 있지만 **알림은 하나만 돌려준다** —
  /// 진동과 화면은 하나뿐이고, 나머지 장소의 상태·이력은 정상 기록된다.
  /// 먼저 발견된 것을 쓰는 이유는 목록 순서가 생성 시각 오름차순이라
  /// 결정적이기 때문이다.
  Future<PendingAlert?> handlePosition({required PositionSample sample}) async {
    final places = await _places.findAll();
    PendingAlert? firstAlert;

    for (final place in places) {
      if (!place.enabled) continue;

      final target = _targetOf(place);
      final current = await _states.stateOf(place.id);
      final evaluation = _evaluator.evaluate(
        target: target,
        current: current,
        sample: sample,
      );

      // 상태 저장이 먼저다 — 이후 단계가 실패해도 다음 판정의 기준은 맞아야 한다
      await _states.updateState(place.id, evaluation.state);

      final alert = await _recordAndDecide(
        place: place,
        target: target,
        transition: evaluation.transition,
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracyMeters: sample.accuracyMeters,
      );
      firstAlert ??= alert;
    }

    return firstAlert;
  }
```

`handle()` 은 다음과 같이 후반부를 위임하도록 바꾸고, 알림 발행 대신 `PendingAlert?` 를 돌려주는 형태로 정리한다. **`_alertPort.notify()` 호출은 `handle()` 안에 그대로 남긴다** — 기존 백그라운드 콜백 경로(iOS·폴백)가 그 동작에 의존한다.

```dart
  /// 전이를 이력에 남기고 알림이 필요한지 판단한다.
  ///
  /// 두 진입점([handle]·[handlePosition])이 공유한다 — 여기를 복제하면
  /// OS 경로와 정밀 경로의 규칙이 반드시 어긋난다.
  ///
  /// [accuracyMeters] 가 null 이면 OS 이벤트다. GPS 정확도가 없으므로
  /// 0(완벽)으로 오독되지 않게 -1 을 "정보 없음" 센티널로 쓴다.
  Future<PendingAlert?> _recordAndDecide({
    required AlertPlace place,
    required GeofenceTarget target,
    required GeofenceTransition transition,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    if (transition != GeofenceTransition.entered &&
        transition != GeofenceTransition.exited) {
      return null;
    }

    // 같은 시계에서 갈린다 — 이력은 UTC, 스케줄 판정은 로컬 (이슈 #81)
    final now = _clock();
    final notify = _evaluator.shouldNotify(
      target: target,
      transition: transition,
      localNow: now.toLocal(),
    );

    final occurredAt = now.toUtc();
    await _events.record(
      GeofenceEvent(
        id: _idGenerator(),
        placeId: place.id,
        type: transition == GeofenceTransition.entered
            ? GeofenceEventType.entered
            : GeofenceEventType.exited,
        occurredAt: occurredAt,
        latitude: latitude ?? place.latitude,
        longitude: longitude ?? place.longitude,
        accuracyMeters: accuracyMeters ?? -1,
        notified: notify,
      ),
    );

    if (!notify) return null;

    return PendingAlert(
      placeId: place.id,
      placeName: place.name,
      direction: transition == GeofenceTransition.entered
          ? AlertDirection.enter
          : AlertDirection.exit,
      soundEnabled: place.soundEnabled,
      occurredAt: occurredAt,
    );
  }

  /// AlertPlace → GeofenceTarget 매핑 (docs/02-ARCHITECTURE.md 규칙 1)
  GeofenceTarget _targetOf(AlertPlace place) => GeofenceTarget(
    placeId: place.id,
    latitude: place.latitude,
    longitude: place.longitude,
    radiusMeters: place.radiusMeters,
    direction: place.direction,
    enabled: place.enabled,
    schedules: place.schedules,
  );
```

필요한 import 를 추가한다: `../../features/geofence/domain/position_sample.dart`, `../../features/places/domain/alert_place.dart`.

- [ ] **Step 4: 새 테스트와 기존 테스트가 모두 통과하는지 확인한다**

Run: `flutter test test/app/`
Expected: PASS — 신규 6건 + 기존 `geofence_background_processor_test.dart` 전부

기존 테스트가 깨지면 `handle()` 리팩터링이 동작을 바꾼 것이다. 되돌려서 원인을 찾는다.

- [ ] **Step 5: 커밋한다**

```bash
git add lib/app/background/geofence_background_processor.dart test/app/geofence_background_processor_position_test.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 좌표 측정으로 판정하는 진입점을 더한다. 상태 저장과 이력 기록 이후는 OS 전이 경로와 공유해 규칙이 갈라지지 않게 한다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 3: 판정 결과 DTO 와 `WatchEngineHost`

**Files:**
- Create: `lib/app/background/alert_decision.dart`
- Create: `lib/app/background/watch_engine_host.dart`
- Test: `test/app/watch_engine_host_test.dart`

**Interfaces:**
- Consumes: `GeofenceBackgroundProcessor.handlePosition()`·`handle()` (Task 2), `PendingAlertStore`
- Produces:
  - `class AlertDecision { final bool shouldAlert; final String? placeId; final String? placeName; final String? direction; final bool soundEnabled; Map<String, Object?> toMap(); }`
  - `class WatchEngineHost { Future<AlertDecision> onPosition({required double latitude, required double longitude, required double accuracyMeters, required DateTime timestampUtc}); Future<AlertDecision> onOsTransition({required String placeId, required bool entered, double? latitude, double? longitude}); }`

**책임 경계** — `WatchEngineHost` 는 채널에서 온 원시 값을 도메인 타입으로 바꾸고 판정을 위임한 뒤, 결과를 네이티브가 읽을 수 있는 형태로 되돌린다. **판정 규칙을 여기에 두지 않는다.**

- [ ] **Step 1: 실패하는 테스트를 작성한다**

```dart
import 'package:ear_loc_alert/app/background/alert_decision.dart';
import 'package:ear_loc_alert/app/background/watch_engine_host.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:flutter_test/flutter_test.dart';

/// 감시 서비스 엔진의 Dart 진입점 (이슈 #93)
///
/// 네이티브 없이 전 흐름을 검증한다.
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

  test('진입 측정이면 알림 결정을 돌려주고 PendingAlert 를 저장한다', () async {
    final f = _fixture(place: place, initialState: GeofenceState.outside);

    final decision = await f.host.onPosition(
      latitude: 37.56639,
      longitude: 126.9779,
      accuracyMeters: 10,
      timestampUtc: DateTime.utc(2026, 8, 14, 12),
    );

    expect(decision.shouldAlert, isTrue);
    expect(decision.placeName, '독서실');
    expect(decision.direction, 'enter');
    // 화면 승격 후 AlertController 가 이어받는 경로가 살아있어야 한다
    expect(f.store.saved, isNotNull);
    expect(f.store.saved!.placeId, 'place-1');
  });

  test('알림이 필요없으면 shouldAlert 가 false 이고 저장하지 않는다', () async {
    final f = _fixture(place: place, initialState: GeofenceState.inside);

    final decision = await f.host.onPosition(
      latitude: 37.56639,
      longitude: 126.9779,
      accuracyMeters: 10,
      timestampUtc: DateTime.utc(2026, 8, 14, 12),
    );

    expect(decision.shouldAlert, isFalse);
    expect(f.store.saved, isNull);
  });

  test('OS 전이 경로도 같은 결정 형태를 돌려준다', () async {
    final f = _fixture(place: place, initialState: GeofenceState.outside);

    final decision = await f.host.onOsTransition(placeId: 'place-1', entered: true);

    expect(decision.shouldAlert, isTrue);
    expect(decision.direction, 'enter');
  });

  test('판정 중 예외가 나도 던지지 않고 알림 없음으로 떨어진다', () async {
    // 백그라운드 크래시는 사용자에게 보이지 않은 채 감시만 죽인다
    final f = _fixture(place: place, initialState: GeofenceState.outside, throwOnRead: true);

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
}
```

`_fixture` 는 Task 2 의 Fake 저장소들과, `PendingAlert` 를 메모리에 담는 `_FakePendingAlertStore`(필드 `saved`)를 조립해 `({WatchEngineHost host, _FakePendingAlertStore store})` 를 돌려준다. `throwOnRead` 가 true 면 `_FakePlaceRepository.findAll()` 이 예외를 던진다.

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/app/watch_engine_host_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: `alert_decision.dart` 를 구현한다**

```dart
/// 네이티브에 돌려줄 판정 결과 (이슈 #93)
///
/// freezed 를 쓰지 않는 이유는 이것이 **채널 경계의 전송 형태**이기
/// 때문이다. 도메인 값이 아니라 Map 으로 나가는 것이 목적이고,
/// 키 이름이 Kotlin 쪽과 계약이다 — 한 곳에서 눈으로 확인되어야 한다.
class AlertDecision {
  const AlertDecision({
    required this.shouldAlert,
    this.placeId,
    this.placeName,
    this.direction,
    this.soundEnabled = true,
  });

  /// 알림 없음 — 가장 흔한 결과다
  static const none = AlertDecision(shouldAlert: false);

  final bool shouldAlert;
  final String? placeId;
  final String? placeName;

  /// `enter` 또는 `exit`
  final String? direction;
  final bool soundEnabled;

  Map<String, Object?> toMap() => {
    'shouldAlert': shouldAlert,
    'placeId': placeId,
    'placeName': placeName,
    'direction': direction,
    'soundEnabled': soundEnabled,
  };
}
```

- [ ] **Step 4: `watch_engine_host.dart` 를 구현한다**

```dart
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/geofence/domain/position_sample.dart';
import 'alert_decision.dart';
import 'geofence_background_processor.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';

/// 감시 서비스 엔진의 Dart 진입점 (이슈 #93)
///
/// 네이티브 `AlertWatchService` 가 보유한 FlutterEngine 위에서 산다.
/// **UI 가 없다** — BuildContext·위젯 트리 Provider 접근 금지
/// (docs/02-ARCHITECTURE.md 규칙 5).
///
/// 하는 일은 셋뿐이다: 채널의 원시 값을 도메인 타입으로 바꾸고,
/// 판정을 [GeofenceBackgroundProcessor] 에 위임하고, 결과를 네이티브가
/// 읽을 형태로 되돌린다. **판정 규칙을 여기 두지 않는다.**
///
/// 어떤 예외도 밖으로 던지지 않는다 — 백그라운드 크래시는 사용자에게
/// 보이지 않은 채 감시만 죽인다.
class WatchEngineHost {
  WatchEngineHost({
    required GeofenceBackgroundProcessor processor,
    required PendingAlertStore store,
  }) : _processor = processor,
       _store = store;

  final GeofenceBackgroundProcessor _processor;
  final PendingAlertStore _store;

  /// 정밀 모드 위치 측정 하나를 판정한다.
  Future<AlertDecision> onPosition({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime timestampUtc,
  }) {
    return _decide(
      () => _processor.handlePosition(
        sample: PositionSample(
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          timestamp: timestampUtc,
        ),
      ),
    );
  }

  /// OS 지오펜스 전이를 판정한다 (폴백 경로).
  Future<AlertDecision> onOsTransition({
    required String placeId,
    required bool entered,
    double? latitude,
    double? longitude,
  }) {
    return _decide(
      () => _processor.handleTransition(
        placeId: placeId,
        eventType: entered
            ? GeofenceEventType.entered
            : GeofenceEventType.exited,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<AlertDecision> _decide(
    Future<PendingAlert?> Function() evaluate,
  ) async {
    try {
      final alert = await evaluate();
      if (alert == null) return AlertDecision.none;

      // 저장이 먼저다 — 화면이 뜬 뒤 AlertController 가 이 값으로
      // 반복 진동·이어폰 판정·소리까지 이어받는다 (이슈 #63)
      await _store.save(alert);

      return AlertDecision(
        shouldAlert: true,
        placeId: alert.placeId,
        placeName: alert.placeName,
        direction: alert.direction.name,
        soundEnabled: alert.soundEnabled,
      );
    } on Object {
      // 좌표가 담길 수 있으므로 로그도 남기지 않는다 (docs/04 규칙)
      return AlertDecision.none;
    }
  }
}
```

**주의** — 위 코드는 `_processor.handleTransition()` 을 부른다. Task 2 에서 만든 것은 `handle()` 이므로, 이 태스크에서 `GeofenceBackgroundProcessor` 에 `handleTransition()` 을 추가한다. 기존 `handle()` 은 알림 발행까지 하는 iOS·기존 콜백용으로 그대로 두고, `handleTransition()` 은 `_recordAndDecide()` 결과를 그대로 돌려주는 형태로 만든다:

```dart
  /// OS 전이를 판정하고 알림 후보를 돌려준다 (이슈 #93).
  ///
  /// [handle] 과 달리 **알림을 발행하지 않는다** — 발행 주체가
  /// 네이티브 감시 서비스이기 때문이다. 판정 규칙은 완전히 같다.
  Future<PendingAlert?> handleTransition({
    required String placeId,
    required GeofenceEventType eventType,
    double? latitude,
    double? longitude,
  }) async {
    final place = await _places.findById(placeId);
    if (place == null) {
      await _states.remove(placeId);
      return null;
    }

    final current = await _states.stateOf(placeId);
    final evaluation = _evaluator.evaluateOsTransition(
      current: current,
      eventType: eventType,
    );
    await _states.updateState(placeId, evaluation.state);

    return _recordAndDecide(
      place: place,
      target: _targetOf(place),
      transition: evaluation.transition,
      latitude: latitude,
      longitude: longitude,
    );
  }
```

그리고 기존 `handle()` 은 `handleTransition()` 을 호출한 뒤 결과가 있으면 `_alertPort.notify()` 하도록 줄인다.

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/app/`
Expected: PASS — 신규 5건 + Task 2 의 6건 + 기존 전부

- [ ] **Step 6: 커밋한다**

```bash
git add lib/app/background/alert_decision.dart lib/app/background/watch_engine_host.dart lib/app/background/geofence_background_processor.dart test/app/watch_engine_host_test.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 감시 서비스 엔진의 Dart 진입점을 만든다. 채널 원시값을 도메인 타입으로 바꾸고 판정을 위임하며 판정 규칙은 두지 않는다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 4: Android 지오펜스 등록 어댑터 (Dart)

**Files:**
- Create: `lib/features/geofence/data/android_geofence_monitor.dart`
- Modify: `lib/app/background/alert_watch_service.dart`
- Modify: `lib/app/background/alert_watch_channel.dart`
- Modify: `lib/features/geofence/data/native_geofence_monitor.dart` (주석만 — iOS 전용 명시)
- Modify: `lib/app/geofence_providers.dart`
- Test: `test/features/geofence/android_geofence_monitor_test.dart`

**Interfaces:**
- Consumes: `GeofenceMonitor` 인터페이스, `proximityRadiusMeters()` (Task 1)
- Produces: `class AndroidGeofenceMonitor implements GeofenceMonitor` — 채널 `kr.suhsaechan.ear_loc_alert/alert_window` 의 `syncGeofences` 를 호출

- [ ] **Step 1: 실패하는 테스트를 작성한다**

```dart
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/data/android_geofence_monitor.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android 지오펜스 등록 어댑터 (이슈 #93)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kr.suhsaechan.ear_loc_alert/alert_window');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registeredPlaceIds') return <String>['old-place'];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final target = GeofenceTarget(
    placeId: 'place-1',
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
  );

  test('sync 는 실제 반경과 근접 반경을 함께 넘긴다', () async {
    await const AndroidGeofenceMonitor().sync([target]);

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    final fences = (call.arguments as Map)['geofences'] as List;
    expect(fences, hasLength(1));

    final fence = fences.first as Map;
    expect(fence['placeId'], 'place-1');
    expect(fence['radiusMeters'], 100.0);
    // 100 × 3 = 300 < 500 → 하한 적용
    expect(fence['proximityRadiusMeters'], 500.0);
  });

  test('빈 목록도 그대로 전달한다 — 전체 해제를 뜻한다', () async {
    await const AndroidGeofenceMonitor().sync([]);

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    expect((call.arguments as Map)['geofences'], isEmpty);
  });

  test('registeredPlaceIds 는 네이티브 응답을 그대로 돌려준다', () async {
    final ids = await const AndroidGeofenceMonitor().registeredPlaceIds();
    expect(ids, ['old-place']);
  });

  test('채널이 없어도 예외를 올리지 않는다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    // 서비스를 못 띄우는 것은 알림이 약해지는 일이지 앱이 멈출 일이 아니다
    await const AndroidGeofenceMonitor().sync([target]);
    expect(await const AndroidGeofenceMonitor().registeredPlaceIds(), isEmpty);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/geofence/android_geofence_monitor_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: `android_geofence_monitor.dart` 를 구현한다**

```dart
import 'package:flutter/services.dart';

import '../domain/geofence_monitor.dart';
import '../domain/geofence_target.dart';
import '../domain/proximity_radius.dart';

/// Android 지오펜스 등록 어댑터 (이슈 #93)
///
/// **왜 native_geofence 를 쓰지 않나** — 그 패키지는 지오펜스 이벤트를
/// WorkManager 로 넘긴다. 즉시 실행 쿼터가 소진되면 일반 작업으로
/// 강등되어 Doze 제한을 받고, 작업 체인이 한 번 실패하면 이후 모든
/// 이벤트가 실행되지 않는다. 앱을 안 쓸수록 알림이 안 오는 구조라
/// 이 앱의 존재 이유와 정면으로 어긋난다.
///
/// 그래서 Android 는 앱이 직접 `GeofencingClient` 에 등록하고, 앱 소유
/// 리시버가 이벤트를 받아 감시 서비스로 직행한다. iOS 는 이 문제가
/// 없어 native_geofence 를 그대로 쓴다.
///
/// **장소마다 지오펜스를 둘 등록한다** — 실제 반경과 근접 반경.
/// 근접 반경은 정밀 감시를 켜는 트리거이고, 실제 반경은 정밀 감시가
/// 실패했을 때의 폴백이다. 하나만 두면 한쪽이 죽을 때 발화가 통째로
/// 사라진다.
class AndroidGeofenceMonitor implements GeofenceMonitor {
  const AndroidGeofenceMonitor();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/alert_window',
  );

  @override
  Future<void> sync(List<GeofenceTarget> targets) async {
    await _invoke('syncGeofences', {
      'geofences': [
        for (final t in targets)
          {
            'placeId': t.placeId,
            'latitude': t.latitude,
            'longitude': t.longitude,
            'radiusMeters': t.radiusMeters.toDouble(),
            'proximityRadiusMeters': proximityRadiusMeters(t.radiusMeters),
          },
      ],
    });
  }

  @override
  Future<void> stopAll() => sync(const []);

  @override
  Future<List<String>> registeredPlaceIds() async {
    try {
      final ids = await _channel.invokeListMethod<String>('registeredPlaceIds');
      return ids ?? const [];
    } on Object {
      return const [];
    }
  }

  /// 어떤 호출도 예외를 올리지 않는다 — 등록 실패는 다음 장소 변경 때
  /// 재시도된다 (GeofenceRegistrationSync._applySafely)
  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object {
      // 위 주석과 같은 이유
    }
  }
}
```

- [ ] **Step 4: 플랫폼 분기를 붙인다**

`lib/app/geofence_providers.dart` 의 `geofenceMonitor` 를 수정한다:

```dart
import 'dart:io' show Platform;
// ... 기존 import
import '../features/geofence/data/android_geofence_monitor.dart';

/// 플랫폼마다 감시 방식이 다르다 (이슈 #93, 결정 017 재검토)
///
/// Android 는 native_geofence 의 WorkManager 경유가 이벤트를 유실시켜
/// 자체 구현으로 대체했다. iOS 는 그 경로가 없어 그대로 쓴다.
@Riverpod(keepAlive: true)
GeofenceMonitor geofenceMonitor(Ref ref) {
  if (Platform.isAndroid) return const AndroidGeofenceMonitor();
  return NativeGeofenceMonitor(callback: geofenceBackgroundCallback);
}
```

`native_geofence_monitor.dart` 의 클래스 주석 첫 줄을 `/// native_geofence 래퍼 — **iOS 전용** (이슈 #93)` 로 바꾸고, Android 에서 쓰지 않는 이유를 두 문장으로 남긴다.

- [ ] **Step 5: codegen 을 돌리고 전체 테스트를 확인한다**

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Expected: analyze 무경고, 전체 테스트 PASS

- [ ] **Step 6: 커밋한다**

```bash
git add lib/features/geofence/data/android_geofence_monitor.dart lib/features/geofence/data/native_geofence_monitor.dart lib/app/geofence_providers.dart lib/app/geofence_providers.g.dart test/features/geofence/android_geofence_monitor_test.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : Android 지오펜스 등록을 자체 채널로 돌린다. 장소마다 실제 반경과 근접 반경을 함께 등록해 정밀 감시가 죽어도 발화가 남는다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 5: Android 의존성과 지오펜스 등록기 (Kotlin)

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/GeofenceRegistrar.kt`
- Create: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/GeofenceReceiver.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: Task 4 의 채널 페이로드 형식 (`placeId`·`latitude`·`longitude`·`radiusMeters`·`proximityRadiusMeters`)
- Produces:
  - `GeofenceRegistrar.sync(fences: List<Map<String, Any?>>)`, `GeofenceRegistrar.registeredIds(): List<String>`
  - 지오펜스 id 규약: 실제 반경은 `{placeId}`, 근접 반경은 `{placeId}#proximity`

**자동 테스트 없음** — 완료 기준은 빌드 통과와 Task 9 의 실기기 확인이다.

- [ ] **Step 1: play-services-location 의존성을 추가한다**

`android/app/build.gradle.kts` 의 `dependencies` 블록:

```kotlin
dependencies {
    // core library desugaring — flutter_local_notifications 요구 (#57)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 지오펜스·정밀 위치를 앱이 직접 다룬다 (이슈 #93).
    // native_geofence 가 transitive 로 가져오지만, 우리 코드가 직접
    // 쓰는 이상 명시한다 — 그 패키지를 걷어낼 때 조용히 깨지면 안 된다.
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
```

- [ ] **Step 2: `GeofenceRegistrar.kt` 를 작성한다**

```kotlin
package kr.suhsaechan.ear_loc_alert

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * OS 지오펜스 등록/해제 (이슈 #93)
 *
 * **왜 직접 등록하나** — native_geofence 는 이벤트를 WorkManager 로 넘긴다.
 * 즉시 실행 쿼터가 소진되면 강등되어 Doze 제한을 받고, 작업 체인이 한 번
 * 실패하면 이후 모든 이벤트가 실행되지 않는다. PendingIntent 목적지가
 * 그 패키지 리시버로 하드코딩돼 있어 가로챌 수도 없다.
 *
 * **장소마다 둘 등록한다.** 실제 반경(`{placeId}`)과 근접 반경
 * (`{placeId}#proximity`). 근접은 정밀 감시를 켜는 트리거이고, 실제는
 * 정밀 감시가 실패했을 때의 폴백이다.
 */
class GeofenceRegistrar(private val context: Context) {

    companion object {
        /** 근접 지오펜스 id 접미사 — 실제 반경과 구분하는 유일한 표식 */
        const val PROXIMITY_SUFFIX = "#proximity"

        fun placeIdOf(geofenceId: String): String =
            geofenceId.removeSuffix(PROXIMITY_SUFFIX)

        fun isProximity(geofenceId: String): Boolean =
            geofenceId.endsWith(PROXIMITY_SUFFIX)
    }

    private val client: GeofencingClient by lazy {
        LocationServices.getGeofencingClient(context)
    }

    /** 마지막으로 등록한 place id 집합. 프로세스가 죽으면 비지만, 앱이 뜰 때 다시 동기화된다 */
    private var registered: Set<String> = emptySet()

    fun registeredIds(): List<String> = registered.toList()

    /**
     * 등록 상태를 [fences] 와 일치시킨다.
     *
     * 전부 지우고 다시 넣는다 — 지오펜스는 같은 id 로 덮어쓰기가 되고,
     * 개수가 최대 40개(장소 20 × 2)라 부분 갱신의 복잡도가 이득보다 크다.
     */
    @SuppressLint("MissingPermission")
    fun sync(fences: List<Map<String, Any?>>) {
        client.removeGeofences(pendingIntent())
        registered = emptySet()
        if (fences.isEmpty()) return

        val geofences = mutableListOf<Geofence>()
        val ids = mutableSetOf<String>()

        for (fence in fences) {
            val placeId = fence["placeId"] as? String ?: continue
            val lat = (fence["latitude"] as? Number)?.toDouble() ?: continue
            val lng = (fence["longitude"] as? Number)?.toDouble() ?: continue
            val radius = (fence["radiusMeters"] as? Number)?.toFloat() ?: continue
            val proximity = (fence["proximityRadiusMeters"] as? Number)?.toFloat() ?: continue

            geofences += buildGeofence(placeId, lat, lng, radius)
            geofences += buildGeofence(placeId + PROXIMITY_SUFFIX, lat, lng, proximity)
            ids += placeId
        }

        if (geofences.isEmpty()) return

        val request = GeofencingRequest.Builder()
            // 등록 시점에 이미 안이면 즉시 ENTER 를 받는다. unknown→inside 는
            // 무알림이므로(도메인 규칙 3) 가짜 알림이 되지 않고, 이게 없으면
            // 등록 직후의 첫 이탈을 통째로 놓친다.
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()

        try {
            client.addGeofences(request, pendingIntent())
            registered = ids
        } catch (error: SecurityException) {
            // 배경 위치 권한이 없다 — 온보딩이 받아야 한다. 조용히 물러난다
        }
    }

    private fun buildGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Float,
    ): Geofence = Geofence.Builder()
        .setRequestId(id)
        .setCircularRegion(latitude, longitude, radiusMeters)
        .setExpirationDuration(Geofence.NEVER_EXPIRE)
        .setTransitionTypes(
            Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
        )
        // 기본 응답성(0) — 빠른 감지가 이 앱의 요구사항이다
        .setNotificationResponsiveness(0)
        .build()

    private fun pendingIntent(): PendingIntent {
        val intent = Intent(context, GeofenceReceiver::class.java)
            .setAction(GeofenceReceiver.ACTION_GEOFENCE_EVENT)
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }
}
```

- [ ] **Step 3: `GeofenceReceiver.kt` 를 작성한다**

```kotlin
package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/**
 * 지오펜스 이벤트 수신 (이슈 #93)
 *
 * **여기서 WorkManager 를 쓰지 않는 것이 이 이슈의 핵심이다.** 큐에 넣는
 * 순간 즉시 실행 쿼터와 Doze 제한 아래로 들어가고, 작업 체인이 한 번
 * 실패하면 이후 이벤트가 조용히 사라진다. 받은 자리에서 감시 서비스로
 * 넘긴다 — 서비스는 이미 떠 있고, 없으면 여기서 띄운다.
 */
class GeofenceReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_GEOFENCE_EVENT = "kr.suhsaechan.ear_loc_alert.GEOFENCE_EVENT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return

        val entered = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> true
            Geofence.GEOFENCE_TRANSITION_EXIT -> false
            // dwell 은 등록하지 않는다
            else -> return
        }

        val triggered = event.triggeringGeofences ?: return
        if (triggered.isEmpty()) return

        // 한 이벤트에 여러 지오펜스가 묶여 올 수 있다. 근접·실제를 나눠
        // 담아 서비스가 각각 다르게 처리하게 한다.
        val proximityIds = ArrayList<String>()
        val placeIds = ArrayList<String>()
        for (fence in triggered) {
            val id = fence.requestId
            if (GeofenceRegistrar.isProximity(id)) {
                proximityIds += GeofenceRegistrar.placeIdOf(id)
            } else {
                placeIds += id
            }
        }

        val location = event.triggeringLocation
        val forward = Intent(context, AlertWatchService::class.java)
            .setAction(AlertWatchService.ACTION_GEOFENCE_EVENT)
            .putExtra(AlertWatchService.EXTRA_ENTERED, entered)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PROXIMITY_IDS, proximityIds)
            .putStringArrayListExtra(AlertWatchService.EXTRA_PLACE_IDS, placeIds)
        if (location != null) {
            forward.putExtra(AlertWatchService.EXTRA_LATITUDE, location.latitude)
            forward.putExtra(AlertWatchService.EXTRA_LONGITUDE, location.longitude)
        }

        try {
            // 서비스가 죽어 있어도 여기서 살아난다 — 이것이 "앱을 한 번도
            // 켜지 않아도 울린다"를 성립시키는 지점이다
            context.startForegroundService(forward)
        } catch (error: Exception) {
            // 백그라운드 서비스 시작 제한에 걸렸다. 다음 이벤트에서 재시도된다
        }
    }
}
```

- [ ] **Step 4: 매니페스트에 리시버를 등록한다**

`AndroidManifest.xml` 의 `<application>` 안, 기존 native_geofence 리시버 선언 **아래**에 추가한다:

```xml
        <!-- 지오펜스 이벤트 수신 (이슈 #93).
             native_geofence 의 리시버는 WorkManager 를 경유해 이벤트가
             지연·유실된다. Android 는 앱이 직접 등록하고 이 리시버가 받는다. -->
        <receiver
            android:name=".GeofenceReceiver"
            android:exported="false" />
```

- [ ] **Step 5: 빌드가 통과하는지 확인한다**

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: 커밋한다**

```bash
git add android/app/build.gradle.kts android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/GeofenceRegistrar.kt android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/GeofenceReceiver.kt android/app/src/main/AndroidManifest.xml
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 지오펜스를 앱이 직접 등록하고 앱 리시버가 받는다. WorkManager 큐를 거치지 않아 쿼터 강등과 체인 실패로 이벤트가 사라지지 않는다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 6: 감시 서비스가 Flutter 엔진을 보유한다 (Kotlin)

**Files:**
- Create: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/WatchEngine.kt`
- Modify: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AlertWatchService.kt`
- Create: `lib/app/background/watch_engine_entrypoint.dart`

**Interfaces:**
- Consumes: `WatchEngineHost` (Task 3), `AlertDecision.toMap()` 키 계약
- Produces:
  - `WatchEngine.start()` / `stop()` / `evaluatePosition(...)` / `evaluateOsTransition(...)`
  - Dart 진입점 `@pragma('vm:entry-point') void watchEngineMain()`

**엔진을 상시 보유하는 것이 이 이슈의 근본 수정이다.** 지금 실패하는 세 지점(콜백 핸들 조회·콜백 정보 조회·엔진 부팅)이 이벤트마다 재실행되기 때문에 발생한다. 한 번 띄워두면 반복되지 않는다.

- [ ] **Step 1: Dart 진입점을 만든다**

`lib/app/background/watch_engine_entrypoint.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/id_generator.dart';
import '../../features/geofence/data/drift_geofence_event_repository.dart';
import '../../features/geofence/data/drift_geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/places/data/drift_place_repository.dart';
import 'background_alert_notifier.dart';
import 'geofence_background_processor.dart';
import 'pending_alert_store.dart';
import 'watch_engine_host.dart';

/// 감시 서비스가 보유하는 엔진의 진입점 (이슈 #93)
///
/// `AlertWatchService` 가 이 함수로 엔진을 띄우고, 이후 이벤트마다
/// 채널로 판정을 요청한다. **이벤트마다 엔진을 새로 띄우지 않는 것이
/// 이 이슈의 핵심 수정이다** — 엔진 부팅은 실패할 수 있고, 그 실패가
/// 반복되면 알림이 통째로 사라진다.
///
/// **UI 가 없다** — BuildContext 접근 금지 (docs/02-ARCHITECTURE.md 규칙 5).
@pragma('vm:entry-point')
void watchEngineMain() {
  WidgetsFlutterBinding.ensureInitialized();

  // 엔진 수명 동안 하나만 연다. 짧은 콜백과 달리 여기서는 연결을
  // 유지해도 되지만, 판정 자체는 장소 목록을 그때그때 읽어 최신을 본다.
  final db = AppDatabase();
  final host = WatchEngineHost(
    processor: GeofenceBackgroundProcessor(
      places: DriftPlaceRepository(db),
      states: DriftGeofenceStateRepository(db),
      events: DriftGeofenceEventRepository(db),
      evaluator: const GeofenceEvaluator(),
      alertPort: BackgroundAlertNotifier(
        plugin: FlutterLocalNotificationsPlugin(),
        store: PendingAlertStore(),
      ),
      idGenerator: IdGenerator.generate,
      clock: DateTime.now,
    ),
    store: PendingAlertStore(),
  );

  const channel = MethodChannel('kr.suhsaechan.ear_loc_alert/watch_engine');
  channel.setMethodCallHandler((call) async {
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'evaluatePosition':
        final decision = await host.onPosition(
          latitude: (args['latitude'] as num).toDouble(),
          longitude: (args['longitude'] as num).toDouble(),
          accuracyMeters: (args['accuracyMeters'] as num).toDouble(),
          timestampUtc: DateTime.fromMillisecondsSinceEpoch(
            (args['timestampMs'] as num).toInt(),
            isUtc: true,
          ),
        );
        return decision.toMap();
      case 'evaluateOsTransition':
        final decision = await host.onOsTransition(
          placeId: args['placeId'] as String,
          entered: args['entered'] as bool,
          latitude: (args['latitude'] as num?)?.toDouble(),
          longitude: (args['longitude'] as num?)?.toDouble(),
        );
        return decision.toMap();
      default:
        return null;
    }
  });

  // 네이티브에 준비 완료를 알린다 — 이 신호 전에 온 이벤트는
  // 서비스가 큐에 담아두었다가 여기서 흘려보낸다
  channel.invokeMethod<void>('engineReady');
}
```

- [ ] **Step 2: `WatchEngine.kt` 를 작성한다**

```kotlin
package kr.suhsaechan.ear_loc_alert

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * 감시 서비스가 보유하는 Flutter 엔진 (이슈 #93)
 *
 * **왜 상시 보유하나** — 예전 구조는 지오펜스 이벤트마다 엔진을 새로
 * 띄웠다. 엔진 부팅은 실패할 수 있고(콜백 핸들 조회·콜백 정보 조회·
 * 엔진 생성), 그 실패가 이벤트마다 재발한다. 한 번 띄워 들고 있으면
 * 그 실패 지점이 통째로 사라진다.
 *
 * 판정은 전부 Dart 에 있다. 이 클래스는 채널을 여닫고 값을 옮길 뿐
 * 어떤 판정도 하지 않는다 (docs/03-DOMAIN.md 규칙 5).
 */
class WatchEngine(private val context: Context) {

    companion object {
        private const val CHANNEL = "kr.suhsaechan.ear_loc_alert/watch_engine"
        private const val ENTRYPOINT = "watchEngineMain"
    }

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false

    /** 엔진 준비 전에 도착한 작업. 준비되면 순서대로 흘려보낸다 */
    private val pending = mutableListOf<() -> Unit>()

    val isRunning: Boolean get() = engine != null

    fun start() {
        if (engine != null) return

        val loader = io.flutter.FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)

        val callback = FlutterCallbackInformation.lookupCallbackInformation(
            io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
                .createDefault().let { 0L }, // placeholder — 아래 주석 참조
        )

        val created = FlutterEngine(context)
        created.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "package:ear_loc_alert/app/background/watch_engine_entrypoint.dart",
                ENTRYPOINT,
            ),
        )

        val ch = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            if (call.method == "engineReady") {
                ready = true
                pending.forEach { it() }
                pending.clear()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        engine = created
        channel = ch
    }

    fun stop() {
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        pending.clear()
    }

    /** 정밀 측정 판정을 요청한다. 결과는 [onDecision] 으로 온다 */
    fun evaluatePosition(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        timestampMs: Long,
        onDecision: (AlertDecision) -> Unit,
    ) {
        invoke(
            "evaluatePosition",
            mapOf(
                "latitude" to latitude,
                "longitude" to longitude,
                "accuracyMeters" to accuracyMeters,
                "timestampMs" to timestampMs,
            ),
            onDecision,
        )
    }

    /** OS 전이 판정을 요청한다 (폴백 경로) */
    fun evaluateOsTransition(
        placeId: String,
        entered: Boolean,
        latitude: Double?,
        longitude: Double?,
        onDecision: (AlertDecision) -> Unit,
    ) {
        invoke(
            "evaluateOsTransition",
            mapOf(
                "placeId" to placeId,
                "entered" to entered,
                "latitude" to latitude,
                "longitude" to longitude,
            ),
            onDecision,
        )
    }

    private fun invoke(
        method: String,
        args: Map<String, Any?>,
        onDecision: (AlertDecision) -> Unit,
    ) {
        val task = {
            channel?.invokeMethod(method, args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    onDecision(AlertDecision.fromMap(result as? Map<*, *>))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    // 판정 실패는 알림 없음으로 떨어진다 — 조용히 넘긴다
                    onDecision(AlertDecision.none())
                }

                override fun notImplemented() = onDecision(AlertDecision.none())
            })
        }
        if (ready) task() else pending += task
    }
}

/**
 * Dart 가 돌려준 판정 결과. 키 이름이 `alert_decision.dart` 와 계약이다.
 */
data class AlertDecision(
    val shouldAlert: Boolean,
    val placeId: String?,
    val placeName: String?,
    val direction: String?,
    val soundEnabled: Boolean,
) {
    companion object {
        fun none() = AlertDecision(false, null, null, null, true)

        fun fromMap(map: Map<*, *>?): AlertDecision {
            if (map == null) return none()
            return AlertDecision(
                shouldAlert = map["shouldAlert"] as? Boolean ?: false,
                placeId = map["placeId"] as? String,
                placeName = map["placeName"] as? String,
                direction = map["direction"] as? String,
                soundEnabled = map["soundEnabled"] as? Boolean ?: true,
            )
        }
    }
}
```

**Step 2 주의** — 위 `start()` 의 `FlutterCallbackInformation` 블록은 잘못된 잔재다. 실제 구현에서는 그 부분을 **삭제하고** `executeDartEntrypoint` 만 쓴다. `DartEntrypoint(bundlePath, library, entrypoint)` 3-인자 생성자가 라이브러리 지정 진입점을 띄우는 정식 경로다. 구현자는 이 지적을 반영해 작성한다.

- [ ] **Step 3: `AlertWatchService` 를 수정한다**

다음을 변경한다:

1. `WatchEngine` 필드를 추가하고 `onCreate()` 에서 `start()`, `onDestroy()` 에서 `stop()`
2. `GeofenceRegistrar` 필드를 추가
3. SharedPreferences 변경 리스너(`prefsListener`)와 관련 상수·`hasPendingAlert()` 를 **제거**한다 — 발화 신호가 채널 결과로 바뀌었다
4. `ACTION_GEOFENCE_EVENT` 처리를 추가한다

```kotlin
        const val ACTION_GEOFENCE_EVENT = "kr.suhsaechan.ear_loc_alert.GEOFENCE_EVENT"
        const val ACTION_SYNC_GEOFENCES = "kr.suhsaechan.ear_loc_alert.SYNC_GEOFENCES"

        const val EXTRA_ENTERED = "entered"
        const val EXTRA_PROXIMITY_IDS = "proximity_ids"
        const val EXTRA_PLACE_IDS = "place_ids"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
```

`onStartCommand` 의 `when` 에 분기를 더한다:

```kotlin
            ACTION_GEOFENCE_EVENT -> handleGeofenceEvent(intent)
```

```kotlin
    /**
     * 지오펜스 이벤트를 처리한다 (이슈 #93).
     *
     * 근접 반경은 정밀 감시를 켜고 끈다. 실제 반경은 폴백 판정이다 —
     * 정밀 감시가 죽어 있어도 이 경로로 알림이 나간다.
     */
    private fun handleGeofenceEvent(intent: Intent) {
        val entered = intent.getBooleanExtra(EXTRA_ENTERED, false)
        val proximityIds = intent.getStringArrayListExtra(EXTRA_PROXIMITY_IDS).orEmpty()
        val placeIds = intent.getStringArrayListExtra(EXTRA_PLACE_IDS).orEmpty()
        val latitude = if (intent.hasExtra(EXTRA_LATITUDE)) intent.getDoubleExtra(EXTRA_LATITUDE, 0.0) else null
        val longitude = if (intent.hasExtra(EXTRA_LONGITUDE)) intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0) else null

        if (proximityIds.isNotEmpty()) {
            if (entered) startPreciseTracking() else stopPreciseTrackingIfIdle(proximityIds)
        }

        for (placeId in placeIds) {
            engine.evaluateOsTransition(placeId, entered, latitude, longitude) { decision ->
                if (decision.shouldAlert) beginAlert()
            }
        }
    }
```

`beginAlert()` 는 기존 그대로 두되, 호출 지점이 SharedPreferences 리스너에서 판정 결과로 바뀐다.

- [ ] **Step 4: 빌드가 통과하는지 확인한다**

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 5: 커밋한다**

```bash
git add android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/WatchEngine.kt android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AlertWatchService.kt lib/app/background/watch_engine_entrypoint.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 감시 서비스가 Flutter 엔진을 상시 보유한다. 이벤트마다 엔진을 새로 띄우던 구조가 실패 지점을 반복 생성하던 원인이었다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 7: 정밀 모드 위치 스트림 (Kotlin)

**Files:**
- Create: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/PreciseLocationTracker.kt`
- Modify: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AlertWatchService.kt`

**Interfaces:**
- Consumes: `WatchEngine.evaluatePosition()` (Task 6)
- Produces: `PreciseLocationTracker.start(onLocation)` / `stop()`

- [ ] **Step 1: `PreciseLocationTracker.kt` 를 작성한다**

```kotlin
package kr.suhsaechan.ear_loc_alert

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * 정밀 모드 위치 스트림 (이슈 #93)
 *
 * 근접 반경 안에 있는 동안만 돈다. OS 지오펜스는 감지가 수십 초 늦을 수
 * 있어 "셔틀버스에서 내릴 곳"에는 부족하다. 근처에 왔을 때만 직접 보고
 * 몇 초 안에 판정한다.
 *
 * **주기는 미검증 값이다** — 실기기 배터리 실측 후 확정한다.
 */
class PreciseLocationTracker(private val context: Context) {

    companion object {
        /** 시속 60km(≈17m/s)에서 반경 100m 를 놓치지 않는 간격 */
        private const val INTERVAL_MS = 5_000L
        private const val MIN_INTERVAL_MS = 3_000L

        /** 정지 상태에서 불필요한 갱신을 막는다 */
        private const val MIN_DISPLACEMENT_M = 10f
    }

    private val client: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private var callback: LocationCallback? = null

    val isRunning: Boolean get() = callback != null

    @SuppressLint("MissingPermission")
    fun start(onLocation: (Location) -> Unit) {
        if (callback != null) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, INTERVAL_MS)
            .setMinUpdateIntervalMillis(MIN_INTERVAL_MS)
            .setMinUpdateDistanceMeters(MIN_DISPLACEMENT_M)
            .build()

        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(onLocation)
            }
        }

        try {
            client.requestLocationUpdates(request, cb, context.mainLooper)
            callback = cb
        } catch (error: SecurityException) {
            // 위치 권한이 없다 — 실제 반경 지오펜스 폴백으로 성립한다
        }
    }

    fun stop() {
        callback?.let { client.removeLocationUpdates(it) }
        callback = null
    }
}
```

- [ ] **Step 2: 서비스에 정밀 모드 제어를 붙인다**

`AlertWatchService` 에 추가한다:

```kotlin
    private val tracker by lazy { PreciseLocationTracker(this) }

    /** 정밀 감시를 요구하는 장소들. 비면 스트림을 끈다 */
    private val proximityPlaces = mutableSetOf<String>()

    /** 근접 반경 안에 오래 머물 때의 배터리 보호 상한 */
    private val preciseTimeoutTask = Runnable { stopPreciseTracking() }

    private fun startPreciseTracking(placeIds: List<String>) {
        proximityPlaces += placeIds
        handler.removeCallbacks(preciseTimeoutTask)
        handler.postDelayed(preciseTimeoutTask, PRECISE_TIMEOUT_MS)
        if (tracker.isRunning) return

        tracker.start { location ->
            engine.evaluatePosition(
                latitude = location.latitude,
                longitude = location.longitude,
                accuracyMeters = location.accuracy.toDouble(),
                timestampMs = location.time,
            ) { decision ->
                if (decision.shouldAlert) beginAlert()
            }
        }
    }

    private fun stopPreciseTrackingIfIdle(placeIds: List<String>) {
        proximityPlaces -= placeIds.toSet()
        if (proximityPlaces.isEmpty()) stopPreciseTracking()
    }

    private fun stopPreciseTracking() {
        handler.removeCallbacks(preciseTimeoutTask)
        proximityPlaces.clear()
        tracker.stop()
    }
```

companion object 에 상수를 더한다:

```kotlin
        /** 근접 반경 안 장시간 체류 시 배터리 보호 (30분) */
        private const val PRECISE_TIMEOUT_MS = 30 * 60 * 1000L
```

Task 6 의 `handleGeofenceEvent` 에서 `startPreciseTracking()` 호출을 `startPreciseTracking(proximityIds)` 로 맞춘다. `onDestroy()` 에 `stopPreciseTracking()` 을 더한다.

- [ ] **Step 3: 빌드가 통과하는지 확인한다**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: 커밋한다**

```bash
git add android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/PreciseLocationTracker.kt android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AlertWatchService.kt
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 근접 반경 안에서만 도는 정밀 위치 감시를 더한다. 30분 상한과 근접 이탈로 꺼져 상시 소모가 되지 않는다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 8: 재부팅 복구와 채널 연결 마무리

**Files:**
- Create: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/BootReceiver.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/MainActivity.kt`
- Modify: `lib/app/background/alert_watch_service.dart`
- Modify: `lib/app/background/alert_watch_channel.dart`
- Modify: `lib/app/geofence_registration_sync.dart`

**Interfaces:**
- Consumes: Task 4 의 `syncGeofences` 채널 계약, Task 5 의 `GeofenceRegistrar`
- Produces: 매니페스트 BOOT_COMPLETED 리시버, `MainActivity` 의 `syncGeofences`/`registeredPlaceIds` 핸들러

- [ ] **Step 1: `BootReceiver.kt` 를 작성한다**

```kotlin
package kr.suhsaechan.ear_loc_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 재부팅 후 감시 복구 (이슈 #93)
 *
 * 매니페스트에 RECEIVE_BOOT_COMPLETED 권한과 "재부팅 후 감시 복구"
 * 주석은 있었으나 **정작 이 리시버가 없었다.** 그 결과 재부팅 후
 * 앱을 켜지 않으면 감시 서비스가 죽은 채로 남았다.
 *
 * 지오펜스 등록 자체는 OS 가 재부팅 후 복원하지 않으므로, 서비스가
 * 떠서 엔진을 띄우고 등록을 다시 밀어넣어야 한다.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            context.startForegroundService(
                Intent(context, AlertWatchService::class.java)
                    .setAction(AlertWatchService.ACTION_START_WATCH),
            )
        } catch (error: Exception) {
            // 부팅 직후 서비스 시작이 막혔다 — 앱을 켜면 복구된다
        }
    }
}
```

- [ ] **Step 2: 매니페스트에 등록한다**

```xml
        <!-- 재부팅 후 감시 복구 (이슈 #93).
             권한과 주석만 있고 리시버가 없어, 재부팅 후 앱을 켜지 않으면
             감시가 죽은 채로 남아 있었다. -->
        <receiver
            android:name=".BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
```

- [ ] **Step 3: `MainActivity` 채널에 지오펜스 동기화를 더한다**

`alert_window` 채널의 `when` 에 분기를 추가한다:

```kotlin
                "syncGeofences" -> {
                    val fences = call.argument<List<Map<String, Any?>>>("geofences") ?: emptyList()
                    // 등록은 서비스가 소유한다 — 앱이 죽어도 살아있어야 하기 때문이다
                    val intent = Intent(this, AlertWatchService::class.java)
                        .setAction(AlertWatchService.ACTION_SYNC_GEOFENCES)
                        .putExtra(AlertWatchService.EXTRA_GEOFENCES, ArrayList(fences.map { HashMap(it) }))
                    startForegroundService(intent)
                    result.success(null)
                }
                "registeredPlaceIds" -> result.success(AlertWatchService.registeredPlaceIds())
```

`AlertWatchService` 에 `ACTION_SYNC_GEOFENCES` 처리와, 등록된 id 를 정적으로 노출하는 통로를 더한다 (`companion object` 에 마지막 등록 집합을 보관).

> **Serializable 주의** — `Map<String, Any?>` 를 Intent extra 로 넘기려면 `HashMap` 이어야 한다. 위 코드가 그렇게 변환한다.

- [ ] **Step 4: Dart 인터페이스를 확장한다**

`alert_watch_service.dart` 에 메서드를 더한다:

```dart
  /// 지오펜스 등록을 서비스에 위임한다 (이슈 #93).
  ///
  /// 등록 주체가 서비스인 이유는 **앱이 죽어도 등록이 살아있어야 하기**
  /// 때문이다. 앱이 소유하면 프로세스가 회수될 때 함께 사라진다.
  Future<void> syncGeofences(List<Map<String, Object?>> geofences);
```

`NoopAlertWatchService` 에 빈 구현을, `AlertWatchChannel` 에 `_invoke('syncGeofences', {'geofences': geofences})` 를 더한다.

- [ ] **Step 5: 전체 검증**

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Expected: analyze 무경고 · 전체 테스트 PASS · 빌드 성공

**여기서 하나라도 실패하면 완료로 보고하지 않는다.**

- [ ] **Step 6: 커밋한다**

```bash
git add android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/BootReceiver.kt android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/MainActivity.kt android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AlertWatchService.kt lib/app/background/alert_watch_service.dart lib/app/background/alert_watch_channel.dart lib/app/geofence_registration_sync.dart
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : feat : 재부팅 복구 리시버를 더하고 지오펜스 등록을 서비스가 소유하게 한다. 권한과 주석만 있고 리시버가 없어 재부팅 후 감시가 죽어 있었다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

### Task 9: 문서 갱신과 실기기 검증

**Files:**
- Modify: `docs/10-DECISIONS.md`
- Modify: `docs/05-PLATFORM.md`
- Modify: `docs/11-ROADMAP.md`
- Modify: `CLAUDE.md` (현재 상태 표)

- [ ] **Step 1: 결정 024 를 추가한다**

`docs/10-DECISIONS.md` 끝(미결 섹션 앞)에 추가한다. 형식은 기존 항목을 따른다 — **버린 것 / 근거 / 대가로 감수하는 것 / 재검토 조건**.

핵심 내용:
- 제목: `## 024. Android 는 하이브리드 감시로 전환한다 (017 재검토 조건 발동)`
- 버린 것: Android 에서의 native_geofence 이벤트 경로
- 근거: WorkManager 경유의 두 결함(쿼터 강등·APPEND 체인 실패), PendingIntent 하드코딩으로 가로챌 수 없음, 017 이 FGS 를 버린 근거가 019 로 이미 무효
- 대가: Android 전용 네이티브 코드가 늘고 자동 테스트가 닿지 않는 영역이 생긴다. 정밀 모드 동안 배터리 소모가 는다
- 재검토 조건: 실측에서 배터리 영향이 크면 근접 반경·주기를 줄인다. native_geofence 가 WorkManager 경유를 버리면 되돌린다

017 에 "재검토 결과: 024 참조" 한 줄, 019 의 "깨지기 쉬운 지점"에 "SharedPreferences 키 감시 의존은 024 에서 제거됐다" 한 줄을 더한다.

- [ ] **Step 2: 플랫폼 문서와 로드맵을 갱신한다**

`docs/05-PLATFORM.md` 의 미검증 항목 표에 아래를 더하고, `docs/11-ROADMAP.md` 현황 표와 `CLAUDE.md` 의 "막혀 있는 것과 이유" 표를 이슈 #93 기준으로 고친다.

- [ ] **Step 3: 실기기로 검증한다**

**이 단계 없이는 이슈를 닫지 않는다.** 코드만으로는 닫히지 않는 항목이다.

| # | 확인 | 통과 기준 |
|---|---|---|
| 1 | 앱 완전 종료 후 도착 | 진동과 알림 화면이 뜬다 |
| 2 | 재부팅 후 앱 미실행 상태에서 도착 | 발화된다 |
| 3 | 화면 꺼짐 장시간 방치 후 도착 | 발화된다 |
| 4 | 정밀 모드 전환 지연 | 근접 진입 후 몇 초 내 판정 시작 |
| 5 | 하루 배터리 소모 | 측정값 기록 (파라미터 확정 근거) |
| 6 | 제조사 절전(삼성) 환경 | 감시 서비스 생존 |
| 7 | 중복 발화 없음 | 한 번 도착에 알림 1회 |

진단 명령:

```bash
adb logcat -s GeofenceReceiver AlertWatchService WatchEngine
adb shell dumpsys location | grep -A10 ear_loc_alert
```

- [ ] **Step 4: 커밋한다**

```bash
git add docs/ CLAUDE.md
git commit -m "앱을 켜지 않으면 도착 알림이 발화되지 않음 : docs : Android 하이브리드 감시 전환을 결정 024 로 기록하고 017 재검토 결과와 019 의 깨지기 쉬운 지점 해소를 연결한다 https://github.com/Cassiiopeia/EarLocAlert/issues/93"
```

---

## Self-Review 기록

**스펙 커버리지** — 설계 문서의 각 절을 태스크에 대응시켰다.

| 스펙 절 | 태스크 |
|---|---|
| 6 구조 (엔진 상시 보유) | Task 6 |
| 6 구조 (지오펜스 2개 등록) | Task 4·5 |
| 7 유지 규칙 | Global Constraints + 각 태스크 주석 |
| 8 컴포넌트 | Task 1~8 전부 |
| 9 데이터 흐름 (정밀·폴백) | Task 3(Dart) · Task 6·7(Kotlin) |
| 10 DB 동시 접근 | Task 6 Step 1 (엔진 수명 동안 연결 1개, 판정마다 최신 목록 조회) |
| 11 파라미터 | Task 1(근접 반경) · Task 7(주기·상한) |
| 12 에러 처리 | 각 태스크의 try/catch 와 폴백 주석 |
| 13 iOS | Task 4 Step 4 (플랫폼 분기) |
| 14 테스트 | Task 1~4 |
| 15 실기기 검증 | Task 9 Step 3 |
| 16 문서 | Task 9 |

**알려진 미해결 지점** — Task 6 Step 2 의 `WatchEngine.start()` 초안에 `FlutterCallbackInformation` 잔재가 남아 있다. 해당 스텝에 삭제 지시를 명시해두었으니 구현자는 그것을 따른다.

**타입 일관성** — `AlertDecision` 의 키(`shouldAlert`·`placeId`·`placeName`·`direction`·`soundEnabled`)가 Dart(Task 3)와 Kotlin(Task 6)에서 일치한다. 지오펜스 id 규약(`{placeId}` / `{placeId}#proximity`)이 Task 5 의 `GeofenceRegistrar` 와 `GeofenceReceiver` 에서 일치한다. 채널 이름은 등록·서비스 제어가 `alert_window`, 판정이 `watch_engine` 으로 분리되어 있다.
