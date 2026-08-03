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

## 현재 상태

**앱 코드가 없다.** `lib/main.dart` 는 `flutter create` 기본 템플릿이다. CI/CD 만 완성되어 있다.

다음 작업은 코드가 아니라 **검증 스파이크**다 → `docs/11-ROADMAP.md` Phase 0

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
