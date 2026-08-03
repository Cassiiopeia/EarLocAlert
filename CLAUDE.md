# EarLocAlert — 작업 지침

특정 위치에 도착·출발할 때 **진동으로, 또는 블루투스 이어폰으로만** 알리는 Flutter 앱.

**코드를 쓰기 전에 관련 문서를 읽는다.** 이 파일은 요약이고, 판단 근거는 `docs/` 에 있다.

| 하려는 일 | 읽을 문서 |
|---|---|
| 무엇을 만드는지 파악 | `docs/01-REQUIREMENTS.md` |
| 새 코드를 어디 둘지 | `docs/02-ARCHITECTURE.md` |
| 지오펜스 판정·알림 로직 | `docs/03-DOMAIN.md` |
| 코드 스타일·Riverpod·테스트 | `docs/04-CONVENTIONS.md` |
| 백그라운드·권한·오디오 | `docs/05-PLATFORM.md` |
| 화면을 만들 때 | `docs/06-UX.md` |
| 광고를 건드릴 때 | `docs/07-MONETIZATION.md` |
| CI/CD·시크릿·버전 | `docs/08-OPERATIONS.md` |
| 권한·심사·개인정보 | `docs/09-RELEASE.md` |
| **"왜 이렇게 되어 있나"** | `docs/10-DECISIONS.md` |
| 다음에 할 일 | `docs/11-ROADMAP.md` |

---

## 현재 상태 (2026-08-04 기준)

**Phase 1 의 코드 작업 9단계가 전부 구현됐다.** 남은 것은 실기기 검증과 사용자 작업(지도 API 키·iOS 서명·AdMob)이다. 진행 현황과 남은 작업은 `docs/11-ROADMAP.md` 의 현황 표가 단일 출처다 — **작업을 시작하기 전에 반드시 그 표를 먼저 읽는다.**

구현된 것: 도메인 로직(지오펜스 판정·오디오 경로·광고 빈도) · Drift 저장소 · 권한 온보딩 · 알림 발화/해제 + 알림 화면 · 전면광고 통합 · 위치 목록/등록/편집 · 플랫폼 권한 선언 · **백그라운드 감시(#63, native_geofence — OS 위임)**. 테스트 121건.

**막혀 있는 것과 이유:**

| 작업 | 막힌 이유 |
|---|---|
| 지도 화면 | Google Maps API 키 미발급 (사용자 작업) |
| 실기기 검증 (S-2~S-10) | 실기기 필요 — 백그라운드 감시·오디오 경로의 실동작 확인 |
| iOS TestFlight 배포 | 서명 자산 만료 (#51, 사용자 작업) |
| 실제 광고 송출 | AdMob 앱 미등록 (현재 테스트 ID 로 동작) |

**개발 환경 주의** — Windows PC 는 내부망이라 `flutter pub get` 불가, 검증을 CI 에 위임했다. **Mac(외부망)에서는 로컬 검증이 가능하므로 CI 를 기다릴 필요 없이 `flutter analyze && flutter test` 를 직접 돌린다.** Mac 의 시스템 Flutter(3.38+/Dart 3.10)로는 codegen 이 죽는다(analyzer 7 상한) — **CI 와 동일한 `~/development/flutter-3.35.5/bin/flutter` 를 쓴다** (`export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"`).

---

## 이 환경에서 할 수 없는 것

개발 PC 가 내부망이라 **pub.dev 에 접근할 수 없다. 미러도 없다.**

| 명령 | 가능 |
|---|---|
| `flutter pub get` | **불가** |
| `flutter analyze` · `flutter test` · `flutter build` | **불가** |
| `dart format` | 가능 |

**코드 수정 후에는 `dart format` 만 실행한다.** 빌드·분석은 시도하지 말고 CI 에 맡긴다 → `docs/08-OPERATIONS.md`

---

## 절대 하지 말 것

아래는 **앱의 핵심 가치나 계정을 직접 깨뜨린다.** 예외 없다.

### 1. 광고를 기다렸다가 알림을 해제하지 않는다

```dart
// O — 해제가 먼저
await alertController.dismiss();
unawaited(adsController.maybeShowInterstitial());

// X — 절대
await adsController.showInterstitial();
await alertController.dismiss();
```

광고 로딩 실패·타임아웃·동의 거부 어느 경우에도 **해제는 즉시 완료된다.** 버스에서 급하게 껐는데 진동이 몇 초 더 계속되면 사용자는 앱을 지운다.
→ `docs/02-ARCHITECTURE.md` 규칙 4

### 2. 블루투스 연결을 확인하지 않고 소리를 재생하지 않는다

```dart
// O
if (isBluetoothConnected && place.soundEnabled) { play(); } else { vibrateOnly(); }

// X — 스피커로 샐 수 있다
play();
```

도서관에서 스피커가 한 번 울리면 이 앱은 존재 이유를 잃는다. 오디오 설정이 실패하면 **재시도하지 말고 진동으로 떨어진다.**
→ `docs/03-DOMAIN.md` 규칙 5

### 3. 알림 화면에 광고를 겹치지 않는다

해제 버튼을 누른 **다음 화면**에만 전면광고를 둔다. 알림 화면 위나 해제 버튼 근처에 광고를 두면 우발적 클릭 유도로 **AdMob 계정이 정지**된다. 정지되면 다른 앱의 수익도 함께 끊긴다.
→ `docs/07-MONETIZATION.md`

### 4. feature 끼리 직접 import 하지 않는다

```dart
// features/alert/ 안에서
// import '../../places/domain/place_repository.dart';   // X
```

협력이 필요하면 `app` 계층이 조율한다. 값으로 주고받는다.
→ `docs/02-ARCHITECTURE.md` 규칙 1

### 5. 상태 관리를 혼용하지 않는다

`@riverpod` code generation 만 쓴다. `provider` 패키지·손으로 만든 Provider·화면 데이터의 `setState` 전부 금지다.
→ `docs/04-CONVENTIONS.md`

### 6. 백그라운드 진입점에서 `BuildContext` 를 만지지 않는다

포그라운드 서비스·지오펜스 콜백은 UI 없이 실행된다. 여기서 할 수 있는 것은 **판정·저장·알림 발행**뿐이다.
→ `docs/02-ARCHITECTURE.md` 규칙 5

### 7. 릴리스 로그에 위치 좌표를 남기지 않는다

개인정보다. `print` 도 쓰지 않는다.
→ `docs/04-CONVENTIONS.md`

### 8. 실기기 테스트에 실제 광고 ID 를 쓰지 않는다

무효 트래픽으로 집계되고 반복되면 계정이 정지된다. 디버그 빌드는 테스트 광고 ID 로 **자동 분기**되어야 한다.
→ `docs/08-OPERATIONS.md`

---

## 자주 틀리는 것

| 실수 | 올바른 것 |
|---|---|
| `pubspec.yaml` 의 version 직접 수정 | `version.yml` 이 단일 출처. 워크플로우가 동기화한다 |
| `DateTime.now()` 저장 | `DateTime.now().toUtc()` — 표시할 때만 로컬 변환 |
| 화면 문자열 하드코딩 | MVP 가 한국어만이어도 l10n 을 거친다 |
| 지오펜스 상태를 메모리에 보관 | 재부팅 후 살아 있어야 한다. Drift 에 저장 |
| `unknown → inside` 에 알림 발생 | 밖에 있었던 적이 확인돼야 진입 알림이다 |
| iOS 에 21개 이상 지오펜스 등록 | OS 제한 20개 |

---

## 문서 유지

**설계 판단을 바꿨으면 `docs/10-DECISIONS.md` 에 항목을 추가하고 해당 문서를 함께 고친다.**

검증 스파이크 결과가 나오면 `docs/05-PLATFORM.md` 의 미검증 항목 표와 `docs/10-DECISIONS.md` 의 미결 표를 갱신한다. 결과를 남기지 않으면 6개월 뒤 같은 확인을 다시 하게 된다.

## 커밋

커밋 메시지·PR 본문에 AI 가 작성했다는 흔적을 넣지 않는다.
