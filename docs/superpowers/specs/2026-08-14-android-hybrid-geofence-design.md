# Android 하이브리드 지오펜스 감시 — 설계

작성일: 2026-08-14
관련: 결정 017(재검토 조건 발동) · 019 · 이슈 #63 · #74

---

## 1. 문제

**앱을 켜지 않으면 도착 알림이 발화되지 않는다.** 도착 후 앱을 실행하는 순간에야 울린다.

실기기에서 확인된 사실:

| 확인 항목 | 결과 |
|---|---|
| 감시 서비스(`AlertWatchService`) 생존 | **살아있음** — 상시 알림 표시됨 |
| 배터리 최적화 예외 | **허용됨** — "제한 없음" |
| 도착 시점 알림 발생 | **없음** — 알림·진동 전부 없음 |
| 앱 실행 후 | **즉시 발화** |

서비스도 살아있고 Doze 예외도 받은 상태에서 발화가 없었다. 발화 주체의 문제가 아니라 **이벤트가 도달하지 않는다.**

## 2. 근본 원인

`native_geofence` 1.2.1 의 Android 이벤트 전달 경로:

```
OS 감지 → NativeGeofenceBroadcastReceiver (즉시)
        → WorkManager 큐 적재 후 리시버 종료   ← 끊기는 지점
        → NativeGeofenceBackgroundWorker
        → FlutterEngine 신규 부팅
        → Dart 콜백
```

`NativeGeofenceBroadcastReceiver.kt` 에 두 결함이 있다.

**(a) 즉시 실행이 보장되지 않는다**

```kotlin
.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
```

expedited 쿼터가 소진되면 일반 작업으로 강등된다. 강등된 작업은 Doze 와 앱 대기 버킷 제한을 그대로 받아 수 분~수십 분 지연된다. 쿼터는 앱 사용 빈도에 따라 결정되므로, **앱을 안 쓸수록 알림이 안 온다** — 이 앱의 사용 패턴과 정확히 반대다.

**(b) 한 번 실패하면 이후 전부 실패한다**

```kotlin
workManager.beginUniqueWork(
    Constants.GEOFENCE_CALLBACK_WORK_GROUP,
    ExistingWorkPolicy.APPEND,
    workRequest
)
```

`APPEND` 는 선행 작업 체인의 leaf 뒤에 붙인다. **leaf 가 FAILED 또는 CANCELLED 면 새로 붙는 작업도 같은 상태가 되어 실행되지 않는다.** 그리고 `NativeGeofenceBackgroundWorker` 에는 `Result.failure()` 반환 지점이 셋 있다 — 콜백 핸들 없음, 콜백 정보 조회 실패, 엔진 null.

**구조적 결함은 이것이다: 실패 가능한 엔진 부팅을 이벤트마다 반복한다.**

## 3. 앱을 켜면 울리는 이유

`native_geofence_monitor.dart:48-50` 이 앱 부트스트랩마다 지오펜스를 전부 재등록한다. 그리고 `native_geofence_monitor.dart:84`:

```dart
androidSettings: const ng.AndroidGeofenceSettings(
  initialTriggers: {ng.GeofenceEvent.enter},
```

등록 시점에 이미 반경 안이면 즉시 ENTER 가 발생한다. 앱이 포그라운드라 워커가 곧바로 실행되고, 그제서야 판정이 돈다.

즉 사용자가 겪은 것은 **도착해서 울린 것이 아니라 앱을 켜서 재등록되며 울린 것**이다. 실제 도착 이벤트는 유실됐다.

## 4. 왜 플러그인 경로를 고칠 수 없나

`NativeGeofenceApiImpl.kt:115`:

```kotlin
val intent = Intent(context, NativeGeofenceBroadcastReceiver::class.java)
```

PendingIntent 의 목적지가 플러그인 리시버로 하드코딩되어 있다. 앱 쪽에서 가로챌 수단이 없다. **Android 지오펜스 등록을 직접 하는 것 외에 방법이 없다.**

## 5. 결정 017 재검토

017 은 `native_geofence` 를 택하며 004 의 Android 정밀 감시 원안을 뒤집었다. 근거는 "FGS 는 제조사 절전에 죽고, 죽으면 감시가 통째로 사라진다"였다.

**그 근거는 이미 무효다.** 019 에서 상시 FGS(`AlertWatchService`)를 도입했고, 실기기에서 살아있음이 확인됐다. 죽을까 봐 피했던 것이 이미 돌고 있다.

017 의 재검토 조건("진입 감지 지연이 핵심 시나리오를 깨뜨리면 Android 정밀 모드를 추가한다")이 발동한 상태다. 지연이 아니라 발화 자체가 없었으므로 조건을 초과한다.

## 6. 구조

**핵심 전환 — 이벤트마다 엔진을 띄우는 것을 그만두고, 이미 살아있는 감시 서비스가 엔진을 상시 보유한다.**

```
[평소 — 광역 감시]
  AlertWatchService (상시 FGS)
    ├─ FlutterEngine 상시 보유                        ← 신규
    └─ GeofencingClient 직접 등록                     ← 신규
         ├─ 장소마다 2개 등록: 근접 반경 + 실제 반경
         └─ PendingIntent → GeofenceReceiver          ← 신규
              └─ WorkManager 경유 없음. 서비스로 직행

[근접 반경 진입]
  GeofenceReceiver → 서비스: 정밀 모드 시작
    └─ FusedLocationProviderClient 위치 스트림
         └─ 측정마다 Dart 판정 (GeofenceEvaluator.evaluate)
              └─ entered/exited 확정 → 진동 + 화면 승격

[실제 반경 지오펜스 발화]  ← 폴백 경로
  GeofenceReceiver → 서비스 → Dart 판정(OS 전이 기반)
    └─ 정밀 모드가 죽어 있어도 이 경로로 발화된다

[근접 이탈 또는 상한 도달]
  정밀 모드 종료 → 스트림 해제 → 광역 감시로 복귀
```

**장소마다 지오펜스를 2개 등록하는 이유** — 근접 반경만 등록하면 정밀 모드가 실패했을 때(위치 권한 취소·스트림 오류·엔진 부팅 실패) 도착을 판정할 수단이 사라진다. 실제 반경 지오펜스를 함께 등록해두면 **정밀 모드가 죽어도 OS 가 도착을 알려준다.** 수십 초 늦을 뿐 발화는 된다 — 이것이 017 이 원래 사려던 보장이다.

Android 지오펜스 상한은 앱당 100개라 장소 20개 × 2 = 40개로 여유가 있다. (iOS 20개 제한은 이 경로에 해당하지 않는다 — 13절 참조)

두 경로가 같은 전이를 중복 발화하지 않는 것은 도메인 규칙 4(같은 상태 반복 무알림)가 보장한다. 상태 저장이 단일 출처(Drift)이므로, 어느 경로가 먼저 도착하든 두 번째는 `transition: none` 이 된다.

## 7. 유지하는 규칙

| 규칙 | 출처 | 이 설계에서 |
|---|---|---|
| 판정은 Dart 에만 | 03-DOMAIN 규칙 5 | `GeofenceEvaluator` 변경 없음. 네이티브 포팅 안 함 |
| 네이티브는 소리를 내지 않는다 | CLAUDE.md 절대규칙 2, 019 | 서비스는 진동·화면 승격만 |
| 광고를 기다려 해제하지 않는다 | 02-ARCHITECTURE 규칙 4 | 해당 경로 변경 없음 |
| feature 간 직접 import 금지 | 02-ARCHITECTURE 규칙 1 | 조율은 app 계층(`WatchEngineHost`) |
| 백그라운드에서 BuildContext 금지 | 02-ARCHITECTURE 규칙 5 | 서비스 엔진은 UI 없음 |
| 릴리스 로그에 좌표 금지 | 04-CONVENTIONS | 신규 코드 전부 적용 |

`PendingAlert`(SharedPreferences) 흐름은 **화면 승격 후 `AlertController` 가 세션을 이어받는 경로로 유지한다.** 다만 *발화 신호*로서의 역할은 사라지므로 `AlertWatchService` 의 SharedPreferences 변경 리스너는 제거한다 — 서비스가 판정 결과를 직접 받기 때문이다. 이로써 결정 019 가 "깨지기 쉬운 지점"으로 지목했던 XML 키 감시 의존이 함께 없어진다.

## 8. 컴포넌트

| 컴포넌트 | 층 | 책임 | 상태 |
|---|---|---|---|
| `GeofenceReceiver` | Kotlin | 지오펜스 PendingIntent 수신 → 서비스 전달 | 신규 |
| `GeofenceRegistrar` | Kotlin | `GeofencingClient` 등록/해제 | 신규 |
| `BootReceiver` | Kotlin | 재부팅 후 서비스 복구 | 신규 |
| `AlertWatchService` | Kotlin | 엔진 보유, 정밀 스트림, 진동, 승격 | 변경 |
| `MainActivity` | Kotlin | 채널 유지 (서비스 제어는 앱에서도 가능) | 변경 |
| `WatchEngineHost` | Dart(app) | 서비스 엔진 진입점. 두 판정 경로(정밀 측정·OS 전이)를 받아 `GeofenceBackgroundProcessor` 로 넘기고 결과를 반환 | 신규 |
| `AndroidGeofenceMonitor` | Dart(data) | `GeofenceMonitor` 구현(Android) | 신규 |
| `NativeGeofenceMonitor` | Dart(data) | iOS 전용으로 축소 | 변경 |
| `GeofenceEvaluator` | Dart(domain) | 판정 | **변경 없음** |
| `GeofenceBackgroundProcessor` | Dart(app) | 판정 조율 로직 재사용 | 재사용 |

## 9. 데이터 흐름

**정밀 모드 판정** (근접 반경 안에 있을 때)

```
위치 측정 (Kotlin FusedLocation)
  → MethodChannel evaluatePosition(lat, lng, accuracy, timestampUtc)
     → Dart WatchEngineHost
        → 캐시된 장소 목록으로 GeofenceEvaluator.evaluate()
        → 전이 발생 시에만 Drift 에 상태·이력 저장
        → shouldNotify(방향·스케줄) 판정
     ← { shouldAlert, placeId, placeName, direction, soundEnabled }
  → 서비스: 진동 시작 + 화면 승격 + PendingAlert 저장
```

**폴백 판정** (실제 반경 지오펜스가 발화했을 때)

```
OS 지오펜스 전이 (enter/exit)
  → GeofenceReceiver → 서비스
     → MethodChannel evaluateOsTransition(placeId, eventType)
        → Dart WatchEngineHost
           → GeofenceEvaluator.evaluateOsTransition()  (기존 메서드)
           → 이하 정밀 경로와 동일
     ← 동일한 결과 형태
  → 서비스: 동일 처리
```

두 경로가 **같은 판정 함수와 같은 상태 저장소**로 수렴한다. 진입점만 다르고 그 뒤는 하나다 — 그래서 중복 발화가 구조적으로 불가능하다.

## 10. DB 동시 접근 (리스크)

상시 엔진이 Drift 연결을 붙들면 메인 isolate 와 같은 파일을 두 연결이 잡는다. 기존 백그라운드 콜백은 "열고 즉시 닫는" 짧은 수명이라 문제가 없었다.

**완화:** 정밀 모드 진입 시 장소 목록을 메모리에 캐시한다. 판정은 메모리에서 하고, DB 쓰기는 **상태 전이가 발생했을 때만** 한다. 5초 주기마다 DB 를 여닫지도, 연결을 붙들지도 않는다.

장소 목록이 바뀌면(등록·수정·삭제) 앱이 서비스에 캐시 무효화를 알린다 — 기존 `GeofenceRegistrationSync` 의 `watchAll()` 구독 지점에 붙인다.

## 11. 파라미터

**전부 미검증 추정치다. 실기기 실측(S-2·S-3) 후 확정한다.**

| 항목 | 초기값 | 근거 |
|---|---|---|
| 근접 반경 (정밀 모드 트리거) | `max(장소 반경 × 3, 500m)` | 60km/h 기준 약 30초 전 전환 |
| 실제 반경 (폴백 지오펜스) | 장소 반경 그대로 | 정밀 모드 실패 시의 발화 보장 |
| 정밀 갱신 주기 | 5초 | 60km/h ≈ 17m/s. 반경 100m 를 놓치지 않는다 |
| 정밀 최소 변위 | 10m | 정지 상태에서 불필요한 갱신 억제 |
| 정밀 모드 상한 | 30분 | 근접 반경에 장시간 체류 시 배터리 보호 |
| 판정 채널 타임아웃 | 3초 | 초과 시 해당 측정 폐기, 다음 측정에서 재판정 |
| 진동 상한 | 10분 | 결정 019 유지 |

## 12. 에러 처리

| 상황 | 처리 |
|---|---|
| 엔진 부팅 실패 | 서비스는 유지. 다음 이벤트에서 재시도. **지오펜스 등록은 엔진과 무관하게 살아있다** |
| 위치 권한 취소 | 정밀 모드 진입 실패 → **실제 반경 지오펜스 폴백으로 발화**. 앱에서 온보딩 유도 |
| 정밀 스트림 오류 | 정밀 모드 종료 → 폴백 경로로 성립. 다음 근접 진입에서 재시도 |
| 판정 채널 타임아웃 | 해당 측정 폐기. 상태 변경 없음 |
| 지오펜스 등록 실패 | 다음 장소 목록 변경 시 재시도 (기존 `_applySafely` 패턴) |
| 서비스 강제 종료 | `START_STICKY` + `BootReceiver` |
| 재부팅 | `BootReceiver` → 서비스 시작 → 엔진 부팅 → 지오펜스 재등록 |

## 13. iOS

**변경하지 않는다.**

- iOS 에는 WorkManager 가 없다. `native_geofence` 가 CLLocationManager region monitoring 을 직접 쓰므로 이 결함 자체가 존재하지 않는다
- iOS 상시 정밀 감시는 배터리·심사 리스크가 크다
- iOS 배포는 서명 자산 만료(#51)로 막혀 있어 검증 경로가 없다

`GeofenceMonitor` 인터페이스가 이미 플랫폼을 가리므로 Android 구현만 교체한다. `native_geofence` 의존은 iOS 용으로 유지한다.

## 14. 테스트

| 대상 | 방식 |
|---|---|
| `GeofenceEvaluator` | **변경 없음** — 기존 테스트 그대로 유지 |
| `WatchEngineHost` | 판정 조율 전 흐름. 플랫폼 없이 fake 저장소로 검증 |
| `AndroidGeofenceMonitor` | MethodChannel mock |
| 근접 반경 계산 | 순수 함수 단위 테스트 |
| 정밀 모드 전환·종료 조건 | 상태 기계 단위 테스트 |
| **두 경로 중복 발화 방지** | 정밀 판정과 OS 전이가 같은 진입을 연달아 보고해도 알림은 1회임을 검증 |
| **폴백 경로 성립** | 정밀 모드가 시작되지 않은 상태에서 실제 반경 지오펜스만으로 발화되는지 검증 |

기존 136건은 도메인을 건드리지 않으므로 그대로 통과해야 한다. **통과 확인 전에 완료로 보고하지 않는다.**

## 15. 실기기 검증 항목

코드만으로는 닫히지 않는다. 아래는 실기기에서만 확인된다.

1. 앱을 완전 종료한 상태에서 도착 → 발화되는가
2. 재부팅 후 앱을 켜지 않고 도착 → 발화되는가
3. 화면 꺼짐·장시간 방치 후 도착 → 발화되는가
4. 정밀 모드 전환 시점의 실제 지연
5. 하루 배터리 소모 (파라미터 확정의 근거)
6. 제조사 절전(삼성) 환경에서 서비스 생존

## 16. 문서 갱신

- `docs/10-DECISIONS.md` 에 024 추가 — "Android 는 하이브리드 감시로 전환한다 (017 재검토 조건 발동)"
- 017 에 재검토 결과 링크, 019 의 "깨지기 쉬운 지점" 항목 해소 기록
- `docs/05-PLATFORM.md` 미검증 항목 표 갱신
- `docs/11-ROADMAP.md` 현황 표 갱신

## 17. 범위 밖

- iOS 감시 방식 변경
- 배터리 목표 수치 확정 (결정 005 — 실측 후)
- 알림 화면·광고·오디오 경로 (이번 변경과 무관)
