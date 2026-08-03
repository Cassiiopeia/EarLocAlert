# 02. 아키텍처

## 스택

**혼용하지 않는다.** 같은 일을 하는 방법이 두 가지 있으면 코드베이스가 두 갈래로 자란다. 아래 표의 "쓰지 않는 것"은 권고가 아니라 금지다.

| 영역 | 결정 | 쓰지 않는 것 |
|---|---|---|
| 프레임워크 | Flutter 3.x / Dart 3.9+ | — |
| 상태 관리 | **Riverpod (code generation)** | `provider` 패키지, `setState` 로 하는 화면 상태 관리, `ChangeNotifier` |
| 의존성 주입 | **Riverpod 으로 통일** | `get_it`, `injectable` |
| 라우팅 | **go_router** | `Navigator.push` 직접 호출 |
| 모델 | **Freezed + json_serializable** | 손으로 쓴 `copyWith` · `==` · `fromJson` |
| 로컬 저장소 | **Drift** (SQLite) | Hive, Isar, 도메인 데이터를 SharedPreferences 에 넣는 것 |
| 단순 설정값 | SharedPreferences | — |
| 지도 | google_maps_flutter | — |
| 위치 | geolocator + 플랫폼 지오펜스 | — |
| 알림 | flutter_local_notifications | — |
| 오디오 | audio_session + just_audio | — |
| 광고 | google_mobile_ads + UMP | — |
| 권한 | permission_handler | — |
| 반응형 치수 | flutter_screenutil | 하드코딩된 px |
| 디자인 | **Material 3 + 자체 토큰** (ThemeExtension) | 서드파티 UI 킷 |
| 아이콘 | **Material `Icons.*_outlined`** | filled·rounded 혼용, 별도 아이콘 패키지 |
| 폰트 | Pretendard | — |
| 테스트 | flutter_test + mocktail | — |

선택 근거는 [10-DECISIONS](10-DECISIONS.md) 를 본다.

> 다른 Flutter 프로젝트(RomRom-FE)는 Riverpod 과 Provider 를 함께 쓴다. **이 프로젝트는 그렇게 하지 않는다.** 패키지 목록은 비슷해도 상태 관리 체계는 하나다.

## 구성

```
lib/
├── main.dart                 진입점. 초기화 후 App 실행만 한다
├── app/                      앱 조립 — 라우터 · 테마 · 전역 Provider · 부트스트랩
├── core/                     공통 기반. features 를 모른다
│   ├── result/               Result · Failure
│   ├── logging/              로거
│   ├── error/                예외 정의
│   ├── extensions/
│   ├── constants/
│   └── widgets/              공용 위젯
└── features/
    ├── places/               위치 등록 · 목록 · 편집
    ├── geofence/             백그라운드 모니터링 · 진입/이탈 판정
    ├── alert/                알림 발화 — 진동 · 오디오 · 알림 화면
    ├── ads/                  AdMob 로딩 · 빈도 제어 · 동의
    └── settings/             설정
```

각 feature 내부는 3계층이다.

```
features/<name>/
├── domain/          모델 · 리포지토리 인터페이스 · 판정 로직     (Flutter 를 모른다)
├── data/            리포지토리 구현 · Drift DAO · 플랫폼 채널
└── presentation/    화면 · 위젯 · Riverpod Provider
```

`domain` 에는 `package:flutter` import 가 없다. **UI 도 실기기도 없이 테스트할 수 있어야 하기 때문이다.** 이 앱에서 가장 검증하기 어려운 것이 지오펜스 판정과 오디오 라우팅 결정인데, 그게 위젯 안에 들어가면 실기기에서만 확인할 수 있게 되고 개발 속도가 무너진다.

## 의존 규칙

```
app  ──→  features/*  ──→  core
              └──X──→  다른 feature        (금지)

feature 내부:
presentation ──→ domain
data         ──→ domain        (인터페이스를 구현)
presentation ──X──→ data       (금지)
```

### 규칙 1 — feature 끼리 직접 의존하지 않는다

```dart
// features/alert/ 안에서
// import '../../places/domain/place_repository.dart';   // X

// alert 는 "어떤 장소에 대한 알림인지"를 파라미터로 받는다
class AlertTrigger {
  final String placeId;
  final String placeName;      // O — 값으로 받는다
  final AlertDirection direction;
}
```

feature 간 협력이 필요하면 **`app` 계층이 조율한다.** geofence 가 진입을 판정하면 그 결과를 `app` 이 받아 alert 에 넘긴다. geofence 가 alert 를 직접 호출하지 않는다.

이렇게 하는 이유는 alert 를 places 없이 테스트할 수 있어야 하기 때문이다. "장소 A 진입" 이벤트를 손으로 만들어 넣으면 알림 로직 전체를 검증할 수 있다.

### 규칙 2 — `core` 는 `features` 를 모른다

```dart
// core/widgets/ 안에서
// import '../../features/places/domain/place.dart';   // X
```

`core` 가 특정 feature 를 알기 시작하면 그건 더 이상 공통 기반이 아니다. 공용 위젯이 `Place` 를 받아야 할 것 같으면, 그 위젯은 `features/places/presentation/` 에 있어야 하는 것이다.

### 규칙 3 — `presentation` 은 `data` 를 모른다

```dart
// features/places/presentation/ 안에서
// import '../data/place_dao.dart';                     // X
import '../domain/place_repository.dart';               // O
```

화면은 인터페이스만 본다. 구현 교체(Drift → 다른 저장소)가 화면 코드를 건드리지 않아야 하고, 테스트에서 가짜 리포지토리를 넣을 수 있어야 한다.

## 규칙 4 — `alert` 는 `ads` 를 기다리지 않는다

**이 프로젝트에서 가장 중요한 규칙이다.**

```dart
// O — 해제가 먼저, 광고는 그 다음
await alertController.dismiss();      // 진동·소리 즉시 중단
unawaited(adsController.maybeShowInterstitial());   // 실패해도 무시

// X — 절대 이렇게 하지 않는다
await adsController.showInterstitial();   // 광고 로딩을 기다린다
await alertController.dismiss();          // 그 뒤에야 알림이 멈춘다
```

광고 로딩 실패·타임아웃·네트워크 없음·동의 거부 — 어떤 경우에도 **해제 버튼은 즉시 동작한다.**

버스에서 알림이 울려 급하게 껐는데 광고 로딩 때문에 진동이 3초 더 계속되면, 사용자는 그 앱을 지운다. 광고 수익보다 알림 신뢰성이 먼저다.

의존 방향도 이 원칙을 따른다. `alert` 는 `ads` 를 import 하지 않는다 (규칙 1). 해제 완료를 `app` 계층이 받아 광고 노출을 **시도**한다.

## 규칙 5 — 백그라운드 진입점에서 UI 를 만지지 않는다

백그라운드 콜백(Android 포그라운드 서비스, iOS 지오펜스 콜백)은 앱 UI 가 없는 상태에서도 실행된다. 여기서 `BuildContext` 나 위젯 트리에 접근하면 앱이 죽는다.

```dart
// 백그라운드 핸들러 안에서
// ScaffoldMessenger.of(context)...     // X — context 가 없다
// ref.read(someWidgetProvider)         // X — 위젯 트리에 붙은 Provider 는 없다
```

백그라운드에서 할 수 있는 것은 **판정 · 저장 · 알림 발행**뿐이다. 화면 표시는 알림을 탭해 앱이 뜬 뒤에 일어난다. 상세는 [05-PLATFORM](05-PLATFORM.md).

## 경계를 어떻게 강제하나

규칙을 문서에만 적어두면 지켜지지 않는다. 다음으로 기계가 잡게 한다.

| 수단 | 잡는 것 |
|---|---|
| `custom_lint` + `riverpod_lint` | Riverpod 오용, Provider 누락 |
| `analysis_options.yaml` 의 import 규칙 | feature 간 직접 import, core → features 역참조 |
| `domain` 에 flutter import 금지 검사 | 도메인 계층 오염 |

lint 로 잡히지 않는 규칙 4(광고 대기)는 **테스트로 잡는다.** 광고 로딩을 무한 지연시키는 가짜 구현을 넣고도 해제가 즉시 완료되는지 검증한다 → [04-CONVENTIONS](04-CONVENTIONS.md)
