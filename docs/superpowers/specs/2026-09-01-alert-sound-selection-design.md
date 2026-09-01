# 장소별 알림음 선택과 사용자 음원 — 설계

- **작성일**: 2026-09-01
- **상태**: 설계 확정
- **관련 문서**: [02-ARCHITECTURE](../../02-ARCHITECTURE.md) · [03-DOMAIN](../../03-DOMAIN.md) · [06-UX](../../06-UX.md) · [09-RELEASE](../../09-RELEASE.md) · [10-DECISIONS](../../10-DECISIONS.md)

## 해결하려는 문제

알림음이 **하나뿐이다.** `assets/sounds/alert.wav` 가 전부이고, 장소가 몇 개든 같은 소리가 난다.

이 앱은 장소마다 방향(도착/출발)과 반경과 시간대를 따로 두는데, **소리만 전역이다.** 그래서 소리만으로는 어느 장소인지 알 수 없다. 이어폰을 끼고 졸다 깬 사용자가 "이게 내릴 정거장인가, 아니면 회사 근처를 지나는 것인가"를 화면을 봐야만 판단한다.

두 가지를 더한다.

1. **장소마다 알림음을 고른다** — 앱이 제공하는 프리셋 중에서
2. **자기 음원을 올려서 쓴다** — 기기 안에서만, 다른 곳으로 나가지 않는다

## 무엇을 만드는가

| 항목 | 결정 | 근거 |
|---|---|---|
| 적용 범위 | **장소별** | 방향·반경·시간대가 이미 장소별이다. 소리만 전역이면 일관성이 깨진다 |
| 볼륨·진동 세기 | **전역 유지** (변경 없음) | 그건 기기 환경이지 장소 속성이 아니다 |
| 기본값 | 기존 `alert.wav` | 마이그레이션된 장소의 동작이 바뀌지 않는다 |
| 커스텀 음원 저장 위치 | **앱 전용 디렉토리로 복사** | 아래 "왜 참조하지 않는가" 참조 |
| 커스텀 음원 공유 | **없음** | 기기 밖으로 나가지 않는다. Play UGC 정책 대상이 아니게 된다 |
| 미리듣기 | **이어폰 연결 시에만** | 규칙 2 에 예외를 뚫지 않는다 |
| 파일 접근 방식 | **SAF / DocumentPicker** | 권한 선언이 하나도 안 늘어난다 |

---

## 1. 저장 모델

### 1.1 `AlertSound` — 공유 어휘

`places` 가 고르고 `alert` 이 재생한다. 두 feature 가 공유하므로 `core/domain/` 에 둔다 — `AlertDirection` 과 같은 위치다.

```dart
// lib/core/domain/alert_sound.dart

/// 앱이 내장한 알림음.
///
/// **음원 파일이 준비될 때마다 여기에 한 줄, pubspec 의 assets 에 한 줄을
/// 더한다.** enum 이 곧 목록이라 화면 코드를 고칠 필요가 없다.
enum SoundPreset {
  defaultTone('default', '기본음', 'assets/sounds/alert.wav');
  // bell('bell', '종소리', 'assets/sounds/bell.wav'),
  // electronic('electronic', '전자음', 'assets/sounds/electronic.wav'),
  // siren('siren', '사이렌', 'assets/sounds/siren.wav'),
  // chime('chime', '차임', 'assets/sounds/chime.wav');

  const SoundPreset(this.id, this.label, this.assetPath);
  final String id;
  final String label;
  final String assetPath;

  /// 모르는 id 는 기본음으로 흡수한다 — 앱을 되돌려 설치했을 때
  /// 저장된 값이 사라진 프리셋을 가리킬 수 있다.
  static SoundPreset fromId(String? id) =>
      values.firstWhere((p) => p.id == id, orElse: () => defaultTone);
}

/// 장소에 지정된 알림음. 저장 형식은 `preset:<id>` 또는 `custom:<uuid>`.
sealed class AlertSound {
  const AlertSound();

  static const AlertSound fallback = PresetSound(SoundPreset.defaultTone);

  /// **절대 던지지 않는다.** 깨진 값은 기본음으로 떨어진다 —
  /// 알림음 문자열 하나 때문에 알림이 멎으면 안 된다.
  factory AlertSound.parse(String raw) {
    final i = raw.indexOf(':');
    if (i <= 0) return fallback;
    final (kind, value) = (raw.substring(0, i), raw.substring(i + 1));
    return switch (kind) {
      'preset' => PresetSound(SoundPreset.fromId(value)),
      'custom' when value.isNotEmpty => CustomSoundRef(value),
      _ => fallback,
    };
  }

  String get storageValue;
}

final class PresetSound extends AlertSound {
  const PresetSound(this.preset);
  final SoundPreset preset;
  @override
  String get storageValue => 'preset:${preset.id}';
}

final class CustomSoundRef extends AlertSound {
  const CustomSoundRef(this.id);
  final String id;   // uuid
  @override
  String get storageValue => 'custom:$id';
}
```

`enum` 을 인덱스가 아니라 **문자열 id 로 저장**하는 것은 이 레포의 확립된 규칙이다 (`prefs_vibration_intensity_store.dart` 주석). 프리셋을 중간에 끼워 넣어도 기존 사용자 설정이 안 바뀐다.

### 1.2 `AlertPlace` 필드 추가

```dart
/// 이 장소에 쓸 알림음 (이슈 #121)
///
/// `AlertSound.fallback` 이 아니라 생성자를 직접 쓴다 — freezed 의
/// `@Default` 는 컴파일 타임 상수를 요구하는데, static const 필드 참조가
/// 그 자리에서 평가되지 않는 경우가 있다.
@Default(PresetSound(SoundPreset.defaultTone)) AlertSound sound,
```

> `CustomSoundRef` 라는 이름을 쓰는 이유는 `sounds/domain/custom_sound.dart` 의
> `CustomSound`(메타데이터 모델)와 이름이 겹치기 때문이다. 이쪽은 **id 만 든 참조**고,
> 저쪽은 이름·길이·크기를 가진 실체다.

### 1.3 Drift — 컬럼 하나 + 테이블 하나

**`AlertPlaces.sound`** — `TypeConverter` 로 `AlertSound` ↔ TEXT. `schedules` 가 이미 같은 방식이다.

```dart
// lib/core/database/tables.dart
/// 이 장소의 알림음 (이슈 #121)
///
/// 기본값 `'preset:default'` 가 기존 `assets/sounds/alert.wav` 다.
/// 마이그레이션된 장소는 소리가 그대로다.
TextColumn get sound => text()
    .map(const AlertSoundConverter())
    .withDefault(const Constant('preset:default'))();
```

**`CustomSounds` 테이블** — 사용자가 올린 음원의 메타데이터.

| 컬럼 | 타입 | 내용 |
|---|---|---|
| `id` | TEXT (PK) | uuid. 파일 이름이기도 하다 |
| `displayName` | TEXT | 원본 파일명. 화면에 보여주는 이름 |
| `extension` | TEXT | `mp3` 등. 파일 경로 조립에 쓴다 |
| `durationMs` | INT | 검증 때 얻은 길이 |
| `sizeBytes` | INT | 목록에 표시 |
| `createdAt` | DATETIME | UTC |

### 1.4 파일 경로를 DB 에 넣지 않는다

**`id` 와 `extension` 만 저장하고 경로는 계산한다.**

절대경로를 저장하면 앱 재설치·OS 업데이트로 컨테이너 경로가 바뀌었을 때 전부 죽는다. 이 레포는 이미 `DiagnosticLogFile.resolve()` 로 같은 문제를 풀어놨고, **절대경로를 DB 에 넣는 코드는 한 줄도 없다.**

```dart
// lib/features/sounds/data/custom_sound_file.dart
abstract final class CustomSoundFile {
  static const dirName = 'sounds';

  /// `<applicationSupport>/sounds/`
  ///
  /// **support 디렉토리를 쓴다.** DB 는 documents, 공유 스냅샷은 temporary 인데
  /// 셋 다 목적이 다르다 — 사용자 음원은 영구 보존이 필요하고(temporary 는
  /// OS 가 지운다), iOS 파일 앱에 노출될 이유가 없다(documents 는 노출될 수 있다).
  static Future<Directory> resolveDir() async { ... }

  static Future<File> resolve(String id, String extension) async { ... }
}
```

---

## 2. 폴더 구조

새 feature 를 만든다.

```
lib/
├── core/
│   ├── domain/
│   │   └── alert_sound.dart              ← 신규. 공유 어휘 (AlertSound / SoundPreset)
│   ├── audio/                            ← 신규 디렉토리
│   │   ├── headphone_detector.dart         인터페이스 + 허용 목록 (단일 출처)
│   │   └── audio_session_headphone_detector.dart
│   └── database/
│       ├── tables.dart                   ← CustomSounds 테이블 추가
│       ├── alert_sound_converter.dart    ← 신규
│       └── app_database.dart             ← schemaVersion 3
│
├── features/
│   ├── sounds/                           ← 신규 feature
│   │   ├── domain/
│   │   │   ├── custom_sound.dart             freezed 모델
│   │   │   ├── custom_sound_repository.dart  인터페이스
│   │   │   ├── sound_validator.dart          검증 규칙 (순수 함수)
│   │   │   ├── sound_probe.dart              재생 가능성·길이 확인 인터페이스
│   │   │   └── sound_import_result.dart      성공/실패 사유 sealed
│   │   ├── data/
│   │   │   ├── custom_sound_file.dart        경로 계산
│   │   │   ├── drift_custom_sound_repository.dart
│   │   │   ├── just_audio_sound_probe.dart
│   │   │   └── file_picker_sound_source.dart 파일 선택 (SAF)
│   │   └── presentation/
│   │       ├── sound_picker_sheet.dart       선택 시트
│   │       ├── sound_picker_controller.dart
│   │       └── sound_preview.dart            미리듣기 (이어폰 판정 적용)
│   │
│   ├── alert/
│   │   ├── domain/alert_effects.dart     ← play() 에 소스 인자 추가
│   │   ├── domain/alert_controller.dart  ← 소스 해석 지점
│   │   └── data/alert_sound_service_impl.dart ← asset/file 분기
│   │
│   └── places/
│       ├── domain/alert_place.dart       ← sound 필드
│       ├── data/drift_place_repository.dart ← 매핑 두 줄
│       └── presentation/place_form_screen.dart ← 섹션 + 콜백
│
└── app/
    ├── router.dart                       ← 콜백 배선
    └── alert_sound_resolver.dart         ← 신규. AlertSound → AlertSoundSource
```

### 왜 `alert` 안이 아니라 새 feature 인가

볼륨·진동 세기 저장소가 `alert` 에 있으니 알림음도 거기 두는 게 자연스러워 보인다. 하지만 그것들은 **값 하나**고, 이건 **CRUD 가 있는 자원**이다 — 목록·추가·검증·삭제·파일 수명 관리.

`alert` 의 책임은 "발화"다. 여기에 파일 관리가 들어가면 이미 16개 파일인 feature 가 두 가지 일을 하게 된다. `alert` 은 **주어진 소스를 이어폰일 때만 재생한다**는 책임만 유지한다.

### 이어폰 판정을 `core/audio/` 로 끌어올리는 이유

지금 허용 목록은 `AlertSoundServiceImpl.headphoneTypes` 안에 있다. 미리듣기도 같은 판정을 해야 하는데, **`sounds` 가 `alert` 을 import 하면 규칙 1 위반**이다.

목록을 복사하면 두 곳이 어긋난다 — 그리고 어긋나는 방향이 "새 장치가 한쪽에만 추가됨" 이라 스피커로 새는 사고로 직결된다. **허용 목록은 한 곳에만 있어야 한다.**

`AlertSoundServiceImpl` 은 `HeadphoneDetector` 에 위임하도록 바꾸고, 기존 테스트가 보던 `headphoneTypes` 는 그대로 재노출한다.

---

## 3. feature 경계 — 값으로 주고받는다

```
[places]                    [app]                      [alert]
장소 편집 폼
  "알림음 [기본음 ▸]"
      │ onPickSound 콜백
      └────────────────────→ router 가 sounds 시트를 연다
                             (places 는 sounds 를 모른다)
                                    │
                             AlertSound 를 돌려받음
      ←────────────────────────────┘
  폼 상태 갱신 → 저장

발화 시점
  AlertPlace.sound ──→ AlertSoundResolver ──→ AlertSoundSource ──→ AlertController
                       (custom 이면 파일 경로를 조립,               (파일 시스템도
                        없으면 기본 asset)                          프리셋 목록도 모른다)
```

`onPickOnMap` 이 이미 같은 패턴이다 (`place_form_screen` 은 `context.push` 를 직접 부르지 않고 콜백을 받는다, `router.dart:127-129`).

**두 발화 경로 모두에 값을 실어야 한다.**

| 경로 | 실어 나르는 것 |
|---|---|
| `AlertRequest` (포그라운드) | `AlertSound` |
| `PendingAlert` (백그라운드 → 앱 복귀) | `storageValue` 문자열 (SharedPreferences) |

---

## 4. 재생 경로 변경

### 4.1 `AlertSoundSource`

```dart
// lib/features/alert/domain/alert_effects.dart
sealed class AlertSoundSource {
  const AlertSoundSource();
}
final class AssetSound extends AlertSoundSource {
  const AssetSound(this.assetPath);
  final String assetPath;
}
final class FileSound extends AlertSoundSource {
  const FileSound(this.filePath);
  final String filePath;
}
```

### 4.2 `play()` 시그니처 — nullable 로 더한다

```dart
// 현재
Future<void> play({required double volume});

// 변경
Future<void> play({required double volume, AlertSoundSource? source});
```

**`required` 로 하지 않는다.** `AlertSoundService` 를 구현한 fake 가 테스트 5개 파일에 흩어져 있어서(`alert_controller_test.dart` 에만 3개), required 로 바꾸면 전부 동시에 고쳐야 컴파일된다. `AlertController` 가 `VibrationIntensityStore?` 를 nullable + 폴백으로 받는 것이 이 레포의 확립된 방식이다.

`source` 가 `null` 이면 기존 기본 asset 을 쓴다 — 기존 동작 그대로.

### 4.3 구현 분기

```dart
switch (source) {
  case AssetSound(:final assetPath): await player.setAsset(assetPath);
  case FileSound(:final filePath):   await player.setFilePath(filePath);
  case null:                         await player.setAsset(_defaultAsset);
}
```

**나머지는 손대지 않는다.** 이어폰 판정, 볼륨, `setLoopMode(LoopMode.one)`, `unawaited(player.play())`, 세션 토큰 검사, `AlertSoundException` → 진동 폴백 — 전부 그대로다.

### 4.4 파일이 사라졌을 때

커스텀 음원 파일이 없으면 `setFilePath` 가 실패하고, 그건 `AlertSoundException` 이 되어 **진동만 남는다.** 이건 너무 약하다 — 소리를 내려고 파일까지 올린 사용자다.

그래서 **해석 단계에서 먼저 막는다.**

```dart
// AlertSoundResolver
final file = await CustomSoundFile.resolve(id, ext);
if (!await file.exists()) {
  Diagnostics.log('sound', '커스텀 음원 없음 id=$id → 기본음 폴백');
  return AssetSound(SoundPreset.defaultTone.assetPath);
}
```

재생 단계가 아니라 **해석 단계**인 이유는, 재생 단계의 실패는 "라우팅이 바뀌었을 수 있으니 재시도 금지" 규칙에 걸려 진동으로 떨어져야 하기 때문이다. 파일 부재는 그것과 성격이 다른 실패다.

---

## 5. 검증 — 고른 직후, 복사 전

```dart
// lib/features/sounds/domain/sound_validator.dart
abstract final class SoundLimits {
  static const maxBytes = 5 * 1024 * 1024;   // 5MB
  static const maxDuration = Duration(seconds: 30);
  static const maxCount = 10;
  static const allowedExtensions = {'mp3', 'm4a', 'aac', 'wav', 'ogg'};
}

sealed class SoundImportError { }
final class TooLarge      extends SoundImportError { final int bytes; }
final class TooLong       extends SoundImportError { final Duration duration; }
final class NotPlayable   extends SoundImportError { }
final class LimitReached  extends SoundImportError { }
final class UnsupportedFormat extends SoundImportError { final String extension; }
```

**확장자만 믿지 않는다.** `just_audio` 로 실제 로드를 시도해서 duration 을 얻고, 그게 성공한 것만 통과시킨다. `.mp3` 로 이름만 바꾼 파일은 여기서 걸린다.

검증 순서는 **싼 것부터** — 개수 → 확장자 → 크기 → 실제 재생. 마지막 것만 디코더를 돌린다.

최악의 경우 5MB × 10개 = **50MB**. 사용자가 앱 용량을 걱정한 이력이 있어(진단 로그 회전, #106) 처음부터 상한을 둔다.

---

## 6. 화면

### 6.1 진입 — 장소 편집 폼

`soundEnabled` 스위치 **바로 아래**에 붙인다. 소리를 켠 다음에 무슨 소리인지 고르는 순서다.

```
소리     ● 켜기
         이어폰이 연결되어 있을 때만 재생됩니다

알림음   ┌──────────────────────────┐
         │ 🔔  기본음            ▸ │
         └──────────────────────────┘
```

`soundEnabled` 가 꺼져 있으면 이 행을 **흐리게 하되 숨기지 않는다.** 숨기면 스위치를 켰을 때 화면이 튄다.

기존 관례대로 `Text(caption)` → `SizedBox(xs)` → 위젯 → `SizedBox(md)` 순서.

### 6.2 선택 시트

라우트가 아니라 **모달 바텀시트**다 (`showModalBottomSheet` + `showDragHandle: true`). 값 하나를 고르는 UI 는 전부 시트라는 것이 이 레포의 관례고, 예외는 지도 선택 화면 하나뿐이다. 목록이 길어질 수 있어 `isScrollControlled: true` 로 연다.

```
┌────────────────────────────────┐
│           ═══                  │
│  알림음                        │
│                                │
│  기본 제공                     │
│  ◉ 기본음                 ▶   │
│  ○ 종소리                 ▶   │
│  ○ 전자음                 ▶   │
│                                │
│  내 음원                 2/10  │
│  ○ 알람소리.mp3    0:03  ▶ ⋮  │
│  ○ ring.m4a        0:08  ▶ ⋮  │
│                                │
│  ┌──────────────────────────┐  │
│  │  ＋  음원 추가            │  │
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

- 고르는 즉시 반영, **확인 버튼 없음** (기존 시트 전부 그렇다)
- `⋮` → 삭제
- `dispose()` 에서 미리듣기를 반드시 멈춘다

### 6.3 미리듣기 — 이어폰이 없으면 못 듣는다

```
┌────────────────────────────────┐
│  🎧 이어폰을 연결하면           │
│     들어볼 수 있습니다          │
└────────────────────────────────┘
```

▶ 버튼을 전부 비활성화하고 목록 위에 이 배너를 띄운다.

**예외를 두고 싶은 유혹이 크다** — 사용자가 방금 누른 것이고, 화면을 보고 있고, 짧다. 그래도 두지 않는다. 이유는 두 가지다.

1. 규칙 2 에 우회 경로가 하나 생기면 그 코드가 다음에 재사용된다. 진동 세기 미리보기는 안전해서 즉시 울리지만 소리는 다르다.
2. **어차피 실제 알림도 이어폰 없이는 안 난다.** 못 들어보는 것이 정확한 재현이다.

시트가 열려 있는 동안 이어폰을 꽂을 수 있으므로, 시트를 열 때 한 번 판정하고 앱이 재개될 때 다시 판정한다.

### 6.4 추가 흐름

```
＋ 음원 추가
   → 시스템 파일 선택기 (권한 요청 없음)
   → 검증 중… (스피너)
       ├ 개수 초과   → "음원은 최대 10개까지입니다"
       ├ 형식 불가   → "지원하지 않는 형식입니다 (mp3, m4a, aac, wav, ogg)"
       ├ 크기 초과   → "파일이 너무 큽니다 (8.2MB / 최대 5MB)"
       ├ 길이 초과   → "너무 깁니다 (1분 12초 / 최대 30초)"
       └ 재생 불가   → "재생할 수 없는 파일입니다"
   → 복사 → 목록에 추가 → 자동 선택
```

**실패 사유를 구체적인 숫자와 함께 말한다.** "파일이 올바르지 않습니다" 로 뭉뚱그리면 사용자는 뭘 고쳐야 할지 모른다.

### 6.5 삭제

```
"알람소리.mp3 을(를) 삭제할까요?
 이 음원을 쓰는 장소 3곳이 기본음으로 바뀝니다."
                          [취소]  [삭제]
```

쓰는 장소가 없으면 개수 문장을 빼고 묻는다. 삭제는 **DB 행과 파일을 함께** 지우고, 그 음원을 쓰던 장소는 기본음으로 갱신한다.

---

## 7. 마이그레이션 — v2 → v3

```dart
schemaVersion = 3;

MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) { ... 기존 ... }
    if (from < 3) {
      await m.addColumn(alertPlaces, alertPlaces.sound);
      await m.createTable(customSounds);
    }
  },
)
```

`m.addColumn` 은 `ALTER TABLE ADD COLUMN` 이라 NOT NULL 컬럼에 **SQL 기본값이 반드시 있어야 한다.** `withDefault(const Constant('preset:default'))` 가 그것이고, `clientDefault` 는 이 자리에 쓸 수 없다.

**주의: `app_database.dart` 상단에 `AlertSoundConverter` 와 `AlertSound` import 를 반드시 넣는다.** `.g.dart` 는 부모의 import 스코프를 쓰는데 analysis 에서 제외되어 있어서, 빠뜨리면 `flutter analyze` 는 통과하고 **실제 컴파일에서만 터진다.** 커밋 `527dda5` 가 정확히 그 사고였다.

**마이그레이션은 백그라운드 isolate 에서도 돈다** (`geofence_callback.dart:30`, `watch_engine_entrypoint.dart:46` 이 `AppDatabase()` 를 직접 연다). `onUpgrade` 안에서 `BuildContext`·플러그인 채널에 의존하면 안 된다.

---

## 8. 기각한 대안

### 대안 1 — 파일 URI 를 그대로 저장

파일 선택기가 준 URI 를 DB 에 넣고 재생할 때 그 URI 를 연다. 복사가 없어 용량을 안 먹는다.

**기각.** 재부팅·앱 재설치 후 URI 권한이 무효가 되고, 사용자가 원본을 옮기거나 지우면 소리가 사라진다. 무엇보다 **재생 시점이 백그라운드**라 그 순간 접근이 막히면 조용히 실패한다. 알림이 안 울리면 이 앱은 존재 이유가 없다.

### 대안 2 — 커스텀 음원을 전역 하나로만

장소별이 아니라 "내 알림음" 하나만 등록. 구현이 훨씬 가볍다.

**기각.** 그러면 소리로 장소를 구분한다는 목적 자체가 사라진다.

### 대안 3 — 시스템 알림음 목록을 쓴다 (`RingtoneManager`)

기기에 이미 있는 알림음을 목록으로 보여준다. 저작권 문제가 0 이고 음원을 구할 필요가 없다.

**기각.** iOS 에 대응물이 없어 플랫폼 분기가 생기고, 기기마다 목록이 달라 "종소리를 골랐는데 다른 폰에서는 없다"가 된다. 무엇보다 네이티브 채널이 하나 더 늘어난다.

### 대안 4 — 프리셋 없이 커스텀만

**기각.** 첫 사용자가 아무 음원도 없이 시작하게 된다. 파일을 올려야만 소리를 고를 수 있는 기능은 대부분 쓰이지 않는다.

---

## 9. 구현 순서 — 로직 먼저, 화면 나중

각 단계가 끝날 때마다 `flutter analyze && flutter test` 가 통과해야 한다.

### 1단계 — 도메인 (Flutter 를 모른다, 전부 테스트 가능)

```
core/domain/alert_sound.dart              AlertSound / SoundPreset
core/audio/headphone_detector.dart        인터페이스 + 허용 목록
sounds/domain/custom_sound.dart           freezed 모델
sounds/domain/sound_validator.dart        SoundLimits + 검증 규칙
sounds/domain/sound_import_result.dart    실패 사유 sealed
sounds/domain/custom_sound_repository.dart
sounds/domain/sound_probe.dart
```

테스트: `AlertSound.parse` 왕복·깨진 값, 검증 경계값, 프리셋 fromId 폴백

### 2단계 — 저장소

```
core/database/alert_sound_converter.dart
core/database/tables.dart                 sound 컬럼 + CustomSounds
core/database/app_database.dart           v3
sounds/data/custom_sound_file.dart        경로 계산
sounds/data/drift_custom_sound_repository.dart
places/domain/alert_place.dart            sound 필드
places/data/drift_place_repository.dart   매핑 두 줄
```

테스트: 컨버터 왕복, 계약 테스트(인메모리), `makePlace` 갱신 3곳

### 3단계 — 발화 경로

```
alert/domain/alert_effects.dart           AlertSoundSource + play(source:)
alert/data/alert_sound_service_impl.dart  asset/file 분기, HeadphoneDetector 위임
alert/domain/alert_controller.dart        소스 전달
app/alert_sound_resolver.dart             해석 + 파일 부재 폴백
AlertRequest / PendingAlert               필드 추가
```

테스트: 소스별 재생 호출, 파일 부재 → 기본음, 이어폰 없음 → 진동만(기존 유지)

### 4단계 — 파일 가져오기

```
pubspec.yaml                              file_picker 추가
sounds/data/file_picker_sound_source.dart
sounds/data/just_audio_sound_probe.dart
```

테스트: `path_provider` 채널 모킹 (선례: `test/core/diagnostic_log_reader_test.dart`)

### 5단계 — 화면

```
sounds/presentation/sound_picker_sheet.dart
sounds/presentation/sound_picker_controller.dart
sounds/presentation/sound_preview.dart
places/presentation/place_form_screen.dart  섹션 + onPickSound 콜백
app/router.dart                             배선
```

테스트: 시트 선택, 이어폰 없을 때 미리듣기 차단, `_hasUnsavedChanges` 신규/편집 두 갈래

---

## 10. 반드시 있어야 하는 테스트

| 대상 | 확인할 것 |
|---|---|
| `AlertSound.parse` | 정상 왕복 · 알 수 없는 prefix · 빈 문자열 · 사라진 프리셋 id |
| 검증기 | 각 상한의 경계값(이하 통과 / 초과 거부) · 확장자 대소문자 |
| 해석기 | 파일 존재 → `FileSound` · 부재 → 기본 `AssetSound` + 로그 |
| 재생 | `AssetSound` → `setAsset` · `FileSound` → `setFilePath` · `null` → 기본 |
| **기존 판정 유지** | 이어폰 미연결 → 진동만 · 재생 실패 → 재시도 없이 진동 |
| 미리듣기 | 이어폰 없으면 재생 호출이 0회 |
| 폼 | 신규 기본값일 때 `_hasUnsavedChanges == false` |
| 삭제 | 참조 장소가 기본음으로 바뀐다 · 파일이 지워진다 |

`AudioRoute` enum 은 건드리지 않는다 — `audio_route_decider_test.dart` 가 `expect(AudioRoute.values, [headphones, silent])` 로 확장을 막고 있고, 이번 변경은 "무엇을 재생할지"만 바꾸지 "재생할지 말지"는 안 바꾼다.

---

## 11. 로그

CLAUDE.md 규칙 7 의 필수 지점에 걸린다.

| 지점 | 남길 것 |
|---|---|
| 장소 저장 | 기존 로그에 `sound` 추가 (`PlaceActions.save` 안) |
| 오디오 판정 | 어떤 음원으로 재생했는지 |
| 음원 등록 | 원본 이름 · 크기 · 길이 · 결과 |
| 음원 등록 실패 | 사유 |
| 음원 삭제 | id · 영향받은 장소 수 |
| 파일 부재 폴백 | id (원인 추적의 유일한 단서) |

---

## 12. Play Store

| 항목 | 영향 |
|---|---|
| 권한 | **추가 없음.** SAF/DocumentPicker 는 권한 선언이 필요 없다 |
| 데이터 보안 양식 | **변경 없음.** 파일이 기기 밖으로 안 나간다 |
| UGC 정책 | **대상 아님.** 사용자 간 공유가 없다 |
| 프리셋 저작권 | **여기가 유일한 위험이다** ↓ |

**음원은 CC0 또는 Public Domain 만 쓴다.** CC-BY 는 앱 안에 저작자 표시 화면이 필요해져 범위가 커진다. 출처는 `assets/sounds/ATTRIBUTION.md` 에 파일마다 기록한다 — 나중에 분쟁이 생기면 이 파일이 유일한 증거다.

```markdown
| 파일 | 출처 | 라이선스 | 받은 날 | URL |
|---|---|---|---|---|
| bell.wav | Freesound | CC0 | 2026-09-01 | https://... |
```

---

## 13. 알아둘 것

**l10n 인프라가 실제로는 없다.** `docs/04-CONVENTIONS.md` 와 CLAUDE.md 는 `context.l10n.*` 을 쓰라고 하지만 `lib/l10n` 도 `.arb` 파일도 `localizationsDelegates` 도 존재하지 않고, **기존 화면 전부가 한국어를 하드코딩**하고 있다. 이 작업도 하드코딩으로 간다 — 여기서 혼자 l10n 을 도입하면 코드베이스가 두 갈래가 된다. l10n 도입은 별도 작업으로 분리한다.

`flutter_screenutil` 도 같다. 의존성은 있지만 `ScreenUtilInit` 초기화가 없어 `.h`/`.sp` 를 쓰면 런타임에 깨진다. `AppSpacing` 상수(8/16/24/40)를 쓴다.

**CI 는 테스트를 돌리지 않는다.** analyze 와 빌드만 있다. 로컬에서 확인해야 한다.

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```

**전역/장소별 판단이 바뀐다.** `alert_effects.dart:45-49` 와 `vibration_intensity.dart:41-44` 에 "전역 설정이다 — 장소별로 두지 않는다"고 적혀 있다. 볼륨과 진동 세기는 계속 전역이고 음원만 장소별이 되므로, 그 주석의 범위를 명확히 하고 `docs/10-DECISIONS.md` 에 항목을 추가한다.


---

## 14. 구현하며 달라진 것

설계를 그대로 옮기지 못한 지점들이다. **이유를 남긴다** — 문서와 코드가 어긋나 보이는 자리에서 다음 사람이 헤매지 않도록.

### `extension` → `fileExtension`

`extension` 은 Dart 내장 식별자(extension methods)다. 필드명으로 쓸 수는 있지만 Drift·freezed 생성 코드에서 혼란을 줄 수 있어 이름을 바꿨다.

### `AlertSoundSource` 를 `core/audio/` 로 옮겼다

설계에서는 `alert/domain/alert_effects.dart` 에 두려 했으나, **미리듣기(`sounds`)가 같은 타입을 써야 했다.** feature 끼리는 직접 import 할 수 없으므로 `HeadphoneDetector` 와 같은 이유로 `core` 로 올렸다.

`alert_effects.dart` 가 `export` 로 재노출하므로 그 파일을 통해 쓰던 코드는 그대로 동작한다.

### `play()` 의 nullable 인자로도 fake 는 고쳐야 했다

설계에 "`required` 로 하지 않으면 기존 fake 를 안 고쳐도 된다"고 적었는데 **틀렸다.** Dart 는 optional named parameter 를 추가해도 override 하는 쪽이 시그니처를 맞춰야 한다. 테스트 fake 4곳을 결국 수정했다.

nullable 로 둔 이점은 남아 있다 — **호출자**가 인자를 생략할 수 있어 기존 호출부가 안 깨진다.

### `sound_import_result.dart` 를 따로 두지 않았다

실패 사유(`SoundImportError`)를 `sound_validator.dart` 안에 뒀다. `place_validator.dart` 가 `PlaceValidationError` 를 같은 파일에 두는 것과 맞춘다 — 검증 규칙과 그 결과를 갈라두면 한쪽만 고쳐진다.

### `SoundImporter` 를 domain 에 추가했다

설계에 없던 것이다. 선택 → 검증 → 프로브 → 등록 순서를 화면에 두면 (1) 비싼 디코딩을 먼저 돌리는 실수가 나기 쉽고 (2) 그 로직을 테스트하려면 위젯을 띄워야 한다. 순수 조율이라 인터페이스만 알면 되므로 domain 에 뒀다.

### 음원을 삭제해도 장소 데이터를 건드리지 않는다

설계에서는 "그 음원을 쓰던 장소를 기본음으로 갱신"하려 했다. **하지 않기로 했다.**

- `sounds` 가 `places` 를 알아야 해서 규칙 1 을 넘는다
- 해석기의 파일 부재 폴백이 이미 그 상황을 처리한다
- `GeofenceEvents` 가 장소 삭제 후에도 남는 것과 같은 판단이다 — 값 참조, 외래키 없음

편집 화면에는 **"삭제된 음원 (기본음으로 알림)"** 으로 표시된다. 사실을 숨기지 않되 데이터를 조용히 고치지도 않는다.

### 폼에 콜백이 두 개 필요했다

`onPickSound` 만으로는 부족했다. **폼이 사용자 음원의 파일명을 알 수 없기 때문**이다 — 그 이름은 `sounds` 의 저장소에 있다. `onDescribeSound` 를 더해 이름 조회를 라우터에 위임했다.

### 시트의 `dispose` 에서 `ref` 를 쓸 수 없다

위젯 테스트가 잡아낸 실제 버그다. riverpod 은 unmount 시 ref 를 먼저 무효화하고 그다음 `State.dispose()` 를 부른다. 거기서 `ref.read` 를 하면 터지고 **미리듣기가 멎지 않은 채 시트만 사라진다.**

`initState` 에서 플레이어 참조를 잡아두는 것으로 고쳤다.

> **같은 패턴이 기존 시트 두 곳에 남아 있다** — `alert_volume_sheet.dart:46`,
> `vibration_intensity_sheet.dart:45`. 이 작업의 범위가 아니라 손대지 않았다.
> 별도 이슈로 다룬다.
