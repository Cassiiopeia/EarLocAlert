# 알림 시간대 스케줄 — 설계

- **작성일**: 2026-08-10
- **상태**: 설계 확정
- **관련 문서**: [03-DOMAIN](../../03-DOMAIN.md) · [02-ARCHITECTURE](../../02-ARCHITECTURE.md) · [10-DECISIONS](../../10-DECISIONS.md)

## 해결하려는 문제

지금은 등록한 장소에 들어가기만 하면 언제든 알림이 울린다. 회사 근처에 살거나 자주 지나는 곳을 등록하면 **하루에도 몇 번씩 무의미하게 울린다.**

사용자가 원하는 것은 "잠실에 도착하면"이 아니라 **"출근길에 잠실에 도착하면"** 이다. 지금 모델에는 그 "언제"를 담을 자리가 없다.

## 무엇을 만드는가

장소마다 **알림이 활성인 시간 구간(창)** 을 0개 이상 붙인다. 창이 없으면 지금처럼 항상 울린다.

```
잠실  [도착]  평일 08:00~10:00
              평일 18:00~20:00
집    [출발]  평일 07:00~09:00
병원  [도착]  (창 없음 — 항상)
```

### 확정된 요구사항

| 항목 | 결정 | 근거 |
|---|---|---|
| 적용 범위 | **장소별.** 전역 설정 없음 | 일회성 약속 장소까지 출퇴근 시간에 묶이면 안 된다 |
| 창이 없을 때 | **항상 활성** | 기존 장소의 동작이 바뀌지 않는다 |
| 창이 여러 개일 때 | **OR** — 하나라도 들면 활성 | |
| 경계 동작 | **창 안에서 발생한 전이만** 알린다 | 창이 열릴 때 이미 안에 있어도 조용하다 |
| 창별 방향 | **없음.** 장소의 `direction` 을 그대로 쓴다 | 창은 "언제", direction 은 "무엇을" — 직교시킨다 |
| 자정 넘김 | **지원.** 요일은 창이 시작된 날 기준 | 막차·야근 귀가가 이 앱의 핵심 사용 상황이다 |

### 경계 동작을 이렇게 정한 이유

07:50 에 잠실에 도착하고 08:00 에 창이 열리면 **알리지 않는다.** 도착한 지 10분 지난 시점에 갑자기 울리는 것은 쓸모가 없고, 집이 창 안에 있으면 매일 아침 알람처럼 울린다. "창이 열려 있는 동안 일어난 진입/이탈"만 알림이 된다.

## 억제 지점 — `shouldNotify`

`GeofenceEvaluator.shouldNotify()` 에 시각을 입력으로 더한다. **OS 지오펜스 등록은 건드리지 않는다.** 창 밖에도 이벤트는 평소대로 들어오고, 상태 전이와 이력은 정상 기록되며, 알림만 나가지 않는다.

기존 주석이 이 설계를 이미 예고하고 있다.

> 전이 판정과 분리한 이유: 전이는 사실이고 알림은 설정이다.
> 이력(GeofenceEvent)은 알림 여부와 무관하게 전이를 전부 기록한다.

스케줄은 "설정" 쪽이다.

### 기각한 대안 1 — 등록 자체를 해제

창 밖이면 `GeofenceRegistrationSync` 에서 OS 등록을 뺀다. 배터리는 아끼지만 **알림을 유실한다.**

등록에서 빠지면 `_states.remove(id)` 로 상태가 `unknown` 이 된다. 이건 의도된 방어 장치다 — 재활성화 때 묵은 `outside` 와 `initialTrigger(ENTER)` 가 만나 가짜 진입 알림이 터지는 것을 막는다. 그 결과 창이 열려 재등록되면 `unknown → inside` 가 되고, [03-DOMAIN](../../03-DOMAIN.md) 규칙 3(`unknown` 첫 판정 무알림)에 걸려 **알림이 나가지 않는다.**

게다가 창 경계마다 앱을 깨울 백그라운드 타이머(Android WorkManager / iOS BGTaskScheduler)와 재부팅 후 타이머 복구가 필요하다. 얻는 것에 비해 대가가 크다.

### 기각한 대안 2 — 알림 발화 직전에 차단

`AlertController` 에서 막으면 **너무 늦다.** 백그라운드에서는 네이티브 `AlertWatchService` 가 진동과 화면 띄우기를 먼저 하고, Dart 의 `AlertController` 는 앱이 전면으로 올라온 뒤에야 관여한다. 여기서 막으면 이미 진동이 울린 뒤이고, 이력의 `notified` 값도 사실과 어긋난다.

---

## 데이터 모델

### `AlertSchedule` — 창 하나

`lib/core/domain/alert_schedule.dart` 에 둔다. `places/domain` 에 두면 geofence 가 places 를 import 하게 되어 [02-ARCHITECTURE](../../02-ARCHITECTURE.md) 규칙 1 을 어긴다. `AlertDirection` 이 이미 `core/domain` 에 있는 것과 같은 이유다.

```dart
@freezed
abstract class AlertSchedule with _$AlertSchedule {
  const factory AlertSchedule({
    /// DateTime.monday(1) ~ DateTime.sunday(7)
    required Set<int> daysOfWeek,

    /// 자정 기준 분 (0 ~ 1439). start > end 이면 자정 넘김.
    required int startMinuteOfDay,
    required int endMinuteOfDay,
  }) = _AlertSchedule;
}
```

**요일은 `Set<int>` 1~7 로 두고 Dart 표준 상수(`DateTime.monday`~`DateTime.sunday`)를 그대로 쓴다.** 자체 enum 을 만들면 `DateTime.weekday` 와 매번 변환해야 하고 그 변환이 틀리기 쉽다.

**`TimeOfDay`(Flutter 타입)를 도메인에 쓰지 않는다.** 도메인은 Flutter 에 의존하지 않는다 — 변환은 표현 계층에서 한다.

### 반복 규칙에는 UTC 를 쓰지 않는다 (UTC 원칙의 예외)

[04-CONVENTIONS](../../04-CONVENTIONS.md) 는 시각을 UTC 로 저장하라고 한다. 그 규칙은 **일어난 사건의 시점**(`createdAt`, `occurredAt`)에 적용된다.

"평일 08:00" 은 시점이 아니라 **벽시계 규칙**이다. UTC 로 저장하면 사용자가 다른 시간대로 이동하거나 서머타임이 적용될 때 08:00 이 07:00 으로 밀린다. 사용자가 원한 것은 "그곳의 아침 8시"이지 "UTC 23시"가 아니다.

자정 기준 분(0~1439) 정수는 시간대와 무관하고, 판정이 정수 비교라 테스트도 명확하다.

**판정에는 로컬 시각을 쓴다.** 같은 `_clock()` 에서 이력은 `.toUtc()`, 판정은 `.toLocal()` 로 갈린다 — 헷갈리기 쉬운 지점이라 코드에 주석으로 이유를 남긴다.

### `AlertPlace` 확장

```dart
/// 빈 목록 = 항상 활성 (기존 동작). 여러 창은 OR.
@Default(<AlertSchedule>[]) List<AlertSchedule> schedules,
```

### 저장 — 별도 테이블 없이 TypeConverter

`AlertPlaces` 테이블에 컬럼 하나를 더한다.

```dart
TextColumn get schedules =>
    text().map(const AlertScheduleListConverter())
          .withDefault(const Constant('[]'))();
```

관계형으로 쪼개지 않는 이유는 **창이 장소 없이 조회되는 경우가 없기 때문**이다. 항상 함께 읽고 함께 쓴다. 별도 테이블로 만들면 백그라운드의 `findById(placeId)` 마다 조인이 붙는데, 그 대가로 얻는 쿼리 능력을 쓸 데가 없다. Drift `TypeConverter` 는 JSON 문자열로 저장하면서 Dart 쪽 타입 안전을 유지한다.

### 마이그레이션

현재 `schemaVersion` 은 1 이고 `MigrationStrategy` 가 정의돼 있지 않다. 2 로 올리며 함께 넣는다.

```dart
int get schemaVersion => 2;

MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) await m.addColumn(alertPlaces, alertPlaces.schedules);
  },
);
```

기본값이 `'[]'` 라 **기존 장소는 전부 "항상 활성"으로 올라온다.** 사용자가 체감하는 변화가 없다.

---

## 판정 로직

```dart
/// 창 하나가 이 시각에 열려 있는가. [localNow] 는 로컬 시각이다.
bool isActiveAt(DateTime localNow) {
  final minute = localNow.hour * 60 + localNow.minute;

  if (startMinuteOfDay <= endMinuteOfDay) {
    return daysOfWeek.contains(localNow.weekday) &&
        minute >= startMinuteOfDay &&
        minute < endMinuteOfDay;
  }

  // 자정 넘김 — 요일은 '창이 시작된 날' 기준이다.
  if (minute >= startMinuteOfDay) {
    return daysOfWeek.contains(localNow.weekday);
  }
  if (minute < endMinuteOfDay) {
    final yesterday = localNow.subtract(const Duration(days: 1)).weekday;
    return daysOfWeek.contains(yesterday);
  }
  return false;
}
```

**구간은 `[start, end)`** — 시작 포함, 끝 제외. 08:00~10:00 과 10:00~12:00 을 나란히 두었을 때 10:00 이 양쪽에 걸치지 않는다.

**`start == end` 는 검증에서 막는다.** 0분짜리 창인지 24시간 창인지 읽는 사람마다 다르게 해석한다. 종일 활성을 원하면 창을 만들지 않으면 되므로(빈 목록 = 항상) 이 모호함을 허용할 이유가 없다.

여러 창은 OR 이다. `isActiveAt` 은 `AlertSchedule` 의 메서드이고, 아래 `isScheduleActive` 는 같은 파일(`lib/core/domain/alert_schedule.dart`)의 최상위 함수다 — 목록을 다루는 관심사라 특정 인스턴스에 매달지 않는다.

```dart
bool isScheduleActive(List<AlertSchedule> schedules, DateTime localNow) {
  if (schedules.isEmpty) return true;
  return schedules.any((s) => s.isActiveAt(localNow));
}
```

### 자정 넘김 예시

`금요일 23:00~02:00` 으로 설정하면:

| 시각 | 판정 |
|---|---|
| 금 23:30 | 창 안 — 오늘(금)이 선택됨 |
| 토 01:30 | 창 안 — 어제(금)가 선택됨 |
| 토 23:30 | 창 밖 — 토요일은 선택 안 함 |

---

## 통합 지점

### 판정 경로 — 세 파일

**`GeofenceTarget`** — 값으로 실어 나른다.

```dart
@Default(<AlertSchedule>[]) List<AlertSchedule> schedules,
```

**`GeofenceEvaluator.shouldNotify`**

```dart
bool shouldNotify({
  required GeofenceTarget target,
  required GeofenceTransition transition,
  required DateTime localNow,
}) {
  if (!target.enabled) return false;
  if (!isScheduleActive(target.schedules, localNow)) return false;
  return switch (transition) { ... };   // 이하 그대로
}
```

**`GeofenceBackgroundProcessor`** — `target` 에 `place.schedules` 를 싣고, 판정에 로컬 시각을 넘긴다.

```dart
final notify = _evaluator.shouldNotify(
  target: target,
  transition: transition,
  localNow: _clock().toLocal(),   // 이력의 occurredAt 은 계속 .toUtc()
);
```

`GeofenceRegistrationSync`(타입 일관성을 위해 `schedules` 를 채우되 등록 판단에는 쓰지 않는다) · 네이티브 코드 · `AlertController` 는 **동작이 바뀌지 않는다.**

### 저장·입력 경로 — 값을 흘려보내는 곳

판정 경로 밖에서도 새 필드가 지나가는 자리가 있다. 기계적인 변경이지만 빠뜨리면 저장이 조용히 유실된다.

| 파일 | 변경 |
|---|---|
| `lib/core/database/tables.dart` | `schedules` 컬럼 + `AlertScheduleListConverter` |
| `lib/core/database/app_database.dart` | `schemaVersion` 2, `MigrationStrategy` 신설 |
| `lib/features/places/data/drift_place_repository.dart` | 행 ↔ 도메인 매핑에 `schedules` 추가 |
| `lib/features/places/presentation/place_list_controller.dart` | `save()` 에 `schedules` 파라미터 추가 |
| `lib/features/places/presentation/place_form_screen.dart` | 상태 보관 + 에디터 삽입 + `save()` 호출에 전달 |
| `lib/features/places/presentation/place_card.dart` | 스케줄 요약 한 줄 표시 |

### 결과

```
평일 08:00~10:00 창이 걸린 잠실 (direction: 도착)

07:50   진입 → 전이 저장 ✓  이력 ✓ (notified=false)  알림 ✗
09:10   진입 → 전이 저장 ✓  이력 ✓ (notified=true)   알림 ✓
14:00   진입 → 전이 저장 ✓  이력 ✓ (notified=false)  알림 ✗
토 09:00 진입 → 창 밖(요일)                            알림 ✗
```

**상태 추적이 한 번도 끊기지 않는 것**이 이 설계의 핵심이다. 창 밖에서도 안팎 상태를 계속 알고 있으므로, 창이 열린 뒤 첫 진입이 정확히 `outside → inside` 로 잡힌다.

---

## UI

`place_form_screen.dart` 는 현재 261줄이고 여기에 요일 칩·시각 피커·목록을 밀어 넣으면 400줄을 넘는다. **위젯 두 개로 분리한다.**

```
lib/features/places/presentation/
  alert_schedule_editor.dart    창 목록 + 추가/삭제 (폼에 끼워 넣는 섹션)
  alert_schedule_sheet.dart     창 하나 편집 (바텀시트)
  alert_schedule_summary.dart   요약 문자열 포맷 (순수 함수)
```

요약 포맷은 표현 계층의 관심사(사람이 읽는 문자열)라 `presentation` 에 두지만, 위젯에 섞지 않고 순수 함수로 분리해 단독 테스트한다.

폼 화면은 상태 하나(`List<AlertSchedule> _schedules`)만 더 들고 에디터에 넘긴다. 분리해두면 나중에 다른 진입점에서 재사용할 수 있다.

### 폼 섹션 — `알림 시점` 바로 아래

```
알림 시간대
┌──────────────────────────────────────┐
│  평일  08:00 ~ 10:00               ✕ │
│  평일  18:00 ~ 20:00               ✕ │
└──────────────────────────────────────┘
  + 시간대 추가

창이 없을 때:
  "항상 알림    시간대를 더하면 그 시간에만 울립니다"
```

### 창 편집 바텀시트

```
  시간대 추가

  요일     [평일] [주말] [매일]        ← 빠른 선택
           월 화 수 목 금 토 일         ← FilterChip 토글

  시작     08:00                       ← showTimePicker
  종료     10:00

  ⚠ 종료가 시작보다 이르면 자정을 넘긴 것으로 봅니다
    (금 23:00~02:00 → 토요일 새벽까지)

              [취소]  [추가]
```

**cron 입력은 넣지 않는다.** cron 은 시점을 표현하는 문법이라 구간을 담지 못한다 — 표현하려면 시작/종료 두 개를 쌍으로 관리해야 하고, 그러면 "이 쌍이 짝이 맞는가"를 검증하는 문제가 새로 생긴다. 요일 + 시각 범위가 담을 수 없는 요구가 실제로 나오면 그때 더한다.

### 목록 카드에도 요약을 보여준다

창 밖이라 안 울린 것을 사용자가 알 방법이 없으면 앱을 믿지 못한다 — 감시 상태를 화면에 드러내라는 F4.5 와 같은 이유다.

요약 문자열은 순수 함수로 만들어 따로 테스트한다.

| 요일 집합 | 표기 |
|---|---|
| 월~금 전부 | `평일` |
| 토·일 | `주말` |
| 7일 전부 | `매일` |
| 그 외 | `월·수·금` |

자정을 넘기면 `23:00~02:00 (익일)`.

### 문자열은 하드코딩으로 둔다

`CLAUDE.md` 는 l10n 을 거치라고 하지만 현재 레포에 `.arb` 가 하나도 없고 전 화면이 한국어 하드코딩이다. 이 기능만 다른 방식을 쓰면 오히려 일관성이 깨진다. F5(다국어)를 할 때 전 화면과 함께 옮긴다.

---

## 테스트

기존 `test/` 구조를 따른다.

| 파일 | 검증 |
|---|---|
| `test/core/alert_schedule_test.dart` | `isActiveAt` — 일반 구간, 자정 넘김(시작일 요일 기준), 경계가 `[start, end)` 인지, 요일 불일치 |
| `test/features/places/alert_schedule_summary_test.dart` | 요약 문자열 — 평일/주말/매일/개별, 익일 표기 |
| `test/features/places/place_validator_test.dart` | `start == end` 거부 |
| `test/features/geofence/geofence_evaluator_test.dart` | 창 밖이면 `shouldNotify == false`, 창 안이면 기존 direction 규칙 그대로 |
| `test/app/geofence_background_processor_test.dart` | **핵심 회귀 가드** (아래) |
| `test/features/places/place_repository_contract_test.dart` | 스케줄 왕복 저장, 빈 목록 기본값 |

### 핵심 회귀 가드

창 밖에서 이벤트가 들어왔을 때 세 가지를 한꺼번에 확인한다.

```
창 밖 진입 이벤트 →
  ① 상태는 inside 로 저장된다        ← 깨지면 창이 열려도 영영 안 울린다
  ② 이력이 notified=false 로 남는다   ← 조사 수단
  ③ alertPort.notify 는 호출되지 않는다
```

**①이 가장 중요하다.** 이 설계의 전제가 "상태 추적은 끊기지 않는다"인데, 누군가 나중에 "창 밖이면 일찍 return 하자"고 최적화하면 조용히 깨진다. 테스트 이름과 주석에 그 이유를 남긴다.

---

## 문서 갱신

| 문서 | 내용 |
|---|---|
| [10-DECISIONS](../../10-DECISIONS.md) | 억제 지점을 `shouldNotify` 로 정한 이유(등록 해제 방식이 왜 알림을 유실하는지) · 반복 규칙에 UTC 를 쓰지 않는 이유 |
| [03-DOMAIN](../../03-DOMAIN.md) | `AlertPlace` 에 `schedules` 추가, 스케줄 판정 규칙 신설 |
| [01-REQUIREMENTS](../../01-REQUIREMENTS.md) | F1.8 신설 |
| [11-ROADMAP](../../11-ROADMAP.md) | 현황 표에 행 추가 |

## 범위 밖

지금 만들지 않는다. 필요가 실제로 확인되면 그때 더한다.

- 전역 기본 스케줄 (장소별로 충분한지 먼저 본다)
- 창별 알림 방향 (창과 direction 을 직교로 유지)
- cron 표현식 입력
- 공휴일 제외 (공휴일 데이터 소스가 필요하고 나라마다 다르다)
- 날짜 범위 한정 (예: 특정 주에만) — 일회성 장소는 그냥 삭제하면 된다
