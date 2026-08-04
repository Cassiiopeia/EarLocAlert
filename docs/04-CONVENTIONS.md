# 04. 코드 규약

[02-ARCHITECTURE](02-ARCHITECTURE.md) 가 "어디에 두는가"라면 이 문서는 "어떻게 쓰는가"다.

## 상태 관리 — Riverpod code generation 만

**손으로 Provider 를 선언하지 않는다.** 전부 `@riverpod` 애노테이션 + 코드 생성이다.

```dart
// O
@riverpod
class PlaceList extends _$PlaceList {
  @override
  Future<List<AlertPlace>> build() => ref.watch(placeRepositoryProvider).findAll();
}

// X — 손으로 만든 Provider
// final placeListProvider = StateNotifierProvider<...>((ref) => ...);
```

이유는 취향이 아니다. 손으로 선언한 Provider 와 생성된 Provider 가 섞이면 **어느 쪽 규칙을 따르는지 파일마다 달라지고**, `riverpod_lint` 가 절반만 검사하게 된다.

### 화면 상태에 `setState` 를 쓰지 않는다

```dart
// X
class _PlaceFormState extends State<PlaceForm> {
  int _radius = 100;
  void _onChanged(int v) => setState(() => _radius = v);
}
```

애니메이션 컨트롤러·텍스트 컨트롤러 같은 **위젯 생명주기에 묶인 자원**은 `StatefulWidget` 을 써도 된다. 하지만 화면이 표시하는 **데이터**는 Provider 에 둔다. 이 경계가 흐려지면 같은 값이 두 곳에 존재하게 된다.

### `ref.read` 는 콜백 안에서만

```dart
// O — build 에서는 watch
final places = ref.watch(placeListProvider);

// O — 버튼 콜백에서는 read
onPressed: () => ref.read(placeListProvider.notifier).delete(id),

// X — build 안에서 read
final places = ref.read(placeListProvider);   // 갱신되지 않는다
```

## 모델 — Freezed

`copyWith`·`==`·`hashCode`·`fromJson` 을 손으로 쓰지 않는다.

```dart
@freezed
class AlertPlace with _$AlertPlace {
  const factory AlertPlace({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required AlertDirection direction,
    @Default(true) bool enabled,
    @Default(true) bool soundEnabled,
    required DateTime createdAt,
  }) = _AlertPlace;

  factory AlertPlace.fromJson(Map<String, dynamic> json) => _$AlertPlaceFromJson(json);
}
```

**여러 상태를 갖는 값은 sealed class 로 만든다.** `bool isLoading` + `String? error` 조합은 "로딩 중이면서 에러"라는 불가능한 상태를 표현할 수 있다.

```dart
@freezed
sealed class GeofenceDecision with _$GeofenceDecision {
  const factory GeofenceDecision.entered() = _Entered;
  const factory GeofenceDecision.exited() = _Exited;
  const factory GeofenceDecision.unchanged() = _Unchanged;
  const factory GeofenceDecision.insufficientAccuracy() = _InsufficientAccuracy;
}
```

`switch` 로 다루면 분기를 빠뜨렸을 때 컴파일이 실패한다.

## 시각 — UTC 저장, 로컬 표시

```dart
// O
final now = DateTime.now().toUtc();

// X — 저장 값에 로컬 시각
final now = DateTime.now();
```

DB·모델·로그는 전부 UTC 다. 로컬 시각으로 바꾸는 것은 **화면에 그리기 직전 한 곳**에서만 한다.

사용자가 해외로 이동하거나 기기 타임존이 바뀌면, 로컬 시각으로 저장된 이력은 순서가 뒤엉킨다. 위치 기반 앱은 사용자가 이동하는 것이 전제다.

## 에러 — 도메인은 `Result`, 인프라는 예외

```dart
// 도메인 — 실패가 정상 흐름의 일부
Result<AlertPlace, PlaceFailure> validate(PlaceInput input);

// 인프라 — 예외를 던지고 경계에서 잡는다
Future<void> save(AlertPlace place);   // Drift 예외가 올라올 수 있다
```

**리포지토리 구현이 인프라 예외를 그대로 위로 올리지 않는다.** `data/` 계층에서 잡아 도메인 실패 타입으로 바꾼다. 화면이 `DriftRemoteException` 을 아는 순간 저장소 교체가 불가능해진다.

### 권한 거부는 에러가 아니다

위치·알림 권한 거부는 예외적 상황이 아니라 **정상적으로 발생하는 상태**다. 예외로 던지지 말고 상태로 표현한다 (A-12).

```dart
@freezed
sealed class PermissionState with _$PermissionState {
  const factory PermissionState.granted() = _Granted;
  const factory PermissionState.denied() = _Denied;
  const factory PermissionState.permanentlyDenied() = _PermanentlyDenied;
  const factory PermissionState.restricted() = _Restricted;
}
```

`permanentlyDenied` 는 앱 설정 화면으로 보내야 하고, `denied` 는 다시 요청할 수 있다. 이 둘을 구분하지 않으면 사용자가 영원히 막힌다.

## 문자열 — 처음부터 하드코딩하지 않는다

MVP 는 한국어만 낸다. 그래도 **화면에 보이는 문자열을 코드에 직접 쓰지 않는다.**

```dart
// O
Text(context.l10n.placeAddTitle)

// X
Text('위치 추가')
```

Phase 2 에서 영어를 붙일 때 전 화면을 다시 여는 일을 피하기 위해서다. 나중에 하려면 화면이 20개일 때가 아니라 3개일 때 해야 한다.

로그 메시지·예외 메시지는 예외다. 사용자에게 보이지 않으므로 코드에 직접 쓴다.

## 치수 — screenutil

```dart
// O
SizedBox(height: 16.h)
Text('...', style: TextStyle(fontSize: 14.sp))

// X
SizedBox(height: 16)
```

예외는 `BorderRadius` 와 아이콘 크기다. 화면 크기에 비례해 늘리면 오히려 어색해진다.

## 로깅

`print` 를 쓰지 않는다. `core/logging` 의 로거를 쓴다.

**릴리스 빌드에 위치 좌표를 로그로 남기지 않는다.** 개인정보다.

```dart
// O
log.d('geofence decision: ${decision.runtimeType} for place=${place.id}');

// X
log.d('position: ${position.latitude}, ${position.longitude}');
```

디버깅에 좌표가 필요하면 디버그 빌드에서만 출력되도록 감싼다.

## 백그라운드 진입점 규약

Android 포그라운드 서비스 콜백과 iOS 지오펜스 콜백은 **앱 UI 없이 실행된다.** 여기서 지켜야 할 것:

| 규칙 | 이유 |
|---|---|
| `BuildContext` 접근 금지 | 존재하지 않는다 |
| 위젯 트리에 붙은 Provider 접근 금지 | 컨테이너가 다르다 |
| 진입점에서 필요한 의존성을 직접 만든다 | DB·알림 채널을 새로 초기화해야 한다 |
| 오래 걸리는 작업 금지 | OS 가 프로세스를 죽인다 |

상세는 [05-PLATFORM](05-PLATFORM.md).

---

## 테스트

### 무엇을 테스트하는가

| 대상 | 테스트 | 이유 |
|---|---|---|
| `domain/` 판정 로직 | **필수** | 실기기 없이 검증할 수 있어야 한다 |
| 오디오 경로 결정 | **필수** | 스피커로 새는지가 앱의 생사다 |
| 광고 빈도 제어 | **필수** | 정책 위반 = 계정 정지 |
| 리포지토리 구현 | 선택 | Drift 자체를 믿는다 |
| 위젯 | 선택 | 비용 대비 효과가 낮다 |

**커버리지 수치를 목표로 삼지 않는다.** 위 세 개가 촘촘하면 충분하다.

### 반드시 있어야 하는 테스트 셋

이 앱에서 놓치면 치명적인 것들이다. 구현할 때 이 목록부터 만든다.

```
지오펜스 판정
  - unknown → inside 는 알림을 만들지 않는다
  - outside → inside 는 알림을 만든다
  - 경계 근처 진동(radius ± 오차)에서 상태가 뒤집히지 않는다
  - accuracy > radius 이면 판정을 보류한다
  - 같은 상태 유지 중에는 알림이 없다

오디오 경로
  - 이어폰(줄·USB-C·블루투스) 연결 + soundEnabled → 이어폰 재생
  - 이어폰 연결 + soundEnabled=false → 진동만
  - 이어폰 미연결 → 진동만
  - 오디오 세션 설정 실패 → 진동만 (스피커 출력 없음)
  - 장치 허용 목록에 유선이 포함되고, 소리가 새는 출력은 제외된다

알림 해제 (02-ARCHITECTURE 규칙 4)
  - 광고 로딩이 영원히 끝나지 않아도 해제가 즉시 완료된다
  - 광고 로딩이 실패해도 해제가 완료된다

광고 빈도
  - 3분 이내 재요청은 거부된다
  - 일일 상한 도달 시 거부된다
```

**"광고 로딩이 영원히 끝나지 않는" 가짜 구현**을 테스트 더블로 만들어 둔다. 이게 규칙 4를 지키는 유일한 자동 검증 수단이다.

### 실기기로만 확인할 수 있는 것

아래는 자동화하지 않는다. [11-ROADMAP](11-ROADMAP.md) 의 검증 체크리스트로 관리한다.

- 백그라운드 지오펜스가 실제로 발화하는가
- 이어폰으로만 소리가 나가는가 (A-05, A-06)
- 재부팅 후 복구되는가
- 배터리 소모량
