# 백그라운드 지오펜스 감시 — 설계 (2026-08-04, 이슈 #63)

## 배경

Phase 1 의 마지막 핵심 조각이다. 장소 저장(#53)·알림 발화(#57)·화면(#61)은 있지만
앱이 화면에 없을 때 위치를 감시하는 기능이 없었다. Phase 0 스파이크 S-1(지오펜스
패키지 선정)이 선행 조건이었고, 외부망(Mac)에서 pub.dev·GitHub 실측 조사로 완료했다.

## S-1 결정: native_geofence

후보 6종 비교(유지보수·Android 14+·iOS 17+·가격·재부팅 복구·동작 방식) 결과
**native_geofence** 를 선정했다. 근거와 탈락 사유는 docs/10-DECISIONS.md 014 에 기록.

- 양 플랫폼 모두 **OS 네이티브 지오펜스 API 위임** (Android GeofencingClient / iOS region monitoring)
- 앱 종료(terminated) 상태에서도 OS 가 콜백 isolate 를 깨움
- 재부팅 복구 내장 (Android BOOT_COMPLETED 재등록 / iOS 는 OS 가 region 유지)
- MIT 무료. 2026-06 까지 활발한 유지보수
- 버전: Flutter 3.35.5(meta 1.16) 호환 상한인 **1.2.1** 사용. 1.3.x 는 최신 툴체인(AGP 9·SPM) 대응이 주된 차이

**설계 변경**: docs/05-PLATFORM.md 의 원래 가정(Android = 포그라운드 서비스 + 직접 폴링)을
버리고 MVP 는 Android 도 OS 위임으로 통일한다. 트레이드오프:

| 얻는 것 | 잃는 것 |
|---|---|
| 상시 알림 없음, 배터리 유리, Android 14 FGS 규제 회피 | 감지 지연이 OS 재량 (수십 초 가능) |
| 앱 종료·재부팅 후에도 OS 가 발화 보장 | "감시 중" 상시 표시 (F4.5 신뢰 표시는 앱 내 상태로 대체) |
| 구현·유지보수 단순 (단일 코드 경로) | 초 단위 정밀 감시 (Phase 2 에서 FGS 정밀 모드 재검토) |

## 아키텍처

```
[OS 지오펜스 이벤트]
      │ (앱 종료 상태여도 OS 가 isolate 를 깨움)
      ▼
app/background/geofence_callback.dart      @pragma('vm:entry-point')
      │  판정·저장·알림 발행만 한다 — BuildContext 금지 (docs/02 규칙 5)
      ▼
app/background/geofence_background_processor.dart   ← 순수 조율 로직 (테스트 대상)
      │  GeofenceEvaluator.evaluateOsTransition() 로 전이 판정
      │  GeofenceStateRepository 상태 갱신 (Drift — 재부팅 생존)
      │  GeofenceEventRepository 이력 기록
      ▼
BackgroundAlertPort (인터페이스)
      │
      ▼
app/background/background_alert_notifier.dart
      │  고중요도 OS 알림 (전용 채널: 진동 패턴 포함) + PendingAlertStore 저장
      ▼
[사용자가 앱을 엶 (알림 탭 또는 직접)]
      ▼
app/pending_alert_launcher.dart — 미처리 알림 확인(TTL 10분) → AlertController.fire() → /alert
```

등록 동기화 (포그라운드):

```
PlaceRepository.watchAll()
      ▼
app/geofence_registration_sync.dart
      │  enabled 만 · createdAt 순 · 최대 20개 (iOS OS 제한, docs/05)
      │  제외된 장소는 OS 등록 해제 + 지오펜스 상태 unknown 으로 리셋
      ▼
GeofenceMonitor (features/geofence/domain 인터페이스)
      ▼
NativeGeofenceMonitor (features/geofence/data) — native_geofence 래퍼
```

## 핵심 판정 규칙 재사용

OS 이벤트는 위치 좌표가 아니라 **전이 자체**를 준다. 기존 판정 규칙을 OS 이벤트용으로 확장:

`GeofenceEvaluator.evaluateOsTransition(current, eventType)`
- ENTER → 다음 상태 inside, EXIT → outside
- 전이는 기존 `_transitionOf` 재사용: `unknown → *` 는 알림 없음, 같은 상태 반복도 없음

이 규칙 재사용이 세 가지 문제를 공짜로 해결한다:
1. **등록 시점에 이미 반경 안** — initialTrigger(ENTER) 를 켜서 상태를 inside 로 초기화하되
   unknown→inside 는 무알림. 이후 이탈이 정상 발화한다 (안 켜면 첫 이탈을 놓친다)
2. **iOS 재부팅 후 중복 발화** (native_geofence 알려진 이슈) — inside→inside 는 transition none
3. **알림 중복 차단** — 도메인 규칙 그대로

## 백그라운드 알림 채널 분리

기존 `ear_loc_alert_alarm` 채널은 진동 off (AlertController 가 직접 반복 진동).
백그라운드 isolate 는 콜백 후 즉시 죽으므로 반복 진동 루프를 돌릴 수 없다 →
**전용 채널 `ear_loc_alert_geofence`** 에 긴 진동 패턴을 위임한다 (Android 채널 설정은
최초 생성 시 고정되므로 채널을 공유하면 안 된다). 소리는 어떤 경우에도 채널에서 내지
않는다 — F3.7(스피커 금지)은 앱 프로세스의 블루투스 확인 후 재생만 허용한다.

## 미처리 알림 핸드오프 (PendingAlert)

백그라운드에서 풀 알림 세션(반복 진동·오디오 판정)을 시작할 수 없으므로:
- 백그라운드: OS 알림 + SharedPreferences 에 PendingAlert 저장 (**cross-isolate 라 읽기 전 reload 필수**)
- 포그라운드 진입 시(탭이든 직접이든): PendingAlertLauncher 가 확인
  - 10분 이내면 AlertController.fire() → /alert 화면 (진동·오디오 시작)
  - 10분 지났으면 버림 (한밤중 알림을 아침에 열었을 때 진동이 터지면 안 된다)

## 이벤트 이력의 한계 기록

OS 이벤트에는 GPS 정확도가 없다 → `accuracyMeters: -1` 센티널 (0 은 "완벽"으로 오독된다).
좌표는 Android 가 주면 실좌표, 아니면 장소 중심 좌표로 대체 (iOS 는 항상 미제공).

## 검증 기반 정비 (선행 수정)

- pubspec `sdk: '>=3.0.0'` → `'>=3.9.0'` — 언어 버전 3.0 탓에 Dart 3.7+ 와일드카드
  문법이 비활성 → analyze 실패가 PR-CI 전체 실패의 근본 원인이었다
- pubspec.lock 재생성 커밋 — 기존 lock 은 내부망 환경 탓에 불완전했다
- 로컬 검증 환경: `~/development/flutter-3.35.5` (CI 와 동일 버전) 병행 설치

## 테스트 계획

| 대상 | 케이스 |
|---|---|
| evaluateOsTransition | unknown→ENTER 무알림 / outside→ENTER 진입 / inside→ENTER 중복 억제 / inside→EXIT 이탈 / unknown→EXIT 무알림 |
| GeofenceBackgroundProcessor | 상태 갱신·이력 기록·notified 플래그 / 방향 필터 / 비활성 무알림 / 장소 없음(고아) 안전 / 전이 없음 시 무기록 |
| GeofenceRegistrationSync | enabled 필터 / 20개 상한 / 제외 장소 등록해제 + 상태 리셋 / 스트림 반응 |
| PendingAlertLauncher | TTL 이내 발화 / TTL 초과 버림 / 없음 no-op |

실기기 검증(S-2~S-5 등)은 별도 세션 — 시뮬레이터로는 지오펜스 발화·블루투스를 확인할 수 없다.

## 하지 않는 것 (YAGNI)

- Android FGS 정밀 모드 — Phase 2, OS 위임의 실측 지연이 부족할 때만
- 근거리 20개 교체 로직 — 사용자가 실제로 20개를 넘길 때 (docs/10 미결 유지)
- iOS 반복 진동(알림 다중 예약) — S-7 실기기 확인 후
