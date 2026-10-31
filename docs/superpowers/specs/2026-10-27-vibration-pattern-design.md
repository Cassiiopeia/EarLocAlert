# 진동 패턴 고르기 (프로) — 설계

이슈 #311. 사용자 요청: "진동 패턴 종류 최대한 많이" (프로 기능 후보 중 선택).

## 왜

- 진동은 이 앱 알림의 대부분이다. 지금은 세기 3단계뿐이라 모든 장소가 같은 진동으로 울린다 — 화면을 보지 않으면 어느 장소인지 모른다.
- 프로 혜택이 장소 개수·알림음·백업·광고뿐이라 iOS(장소 상한 20)에서 무료/프로 차이가 작다.

## 목표 / 비목표

- 목표: 패턴 14종, 설정에서 기본 패턴, 장소별 패턴 지정(없으면 기본 따름), 세 진동 경로(앱 전면 · Android 감시 서비스 · iOS 화면 없이) 모두 같은 패턴.
- 비목표: 사용자가 직접 패턴을 그리는 편집기, 패턴별 소리.
- 금지(실패로 본다): 기본 진동이 지금과 달라지는 것 — 업데이트 후 무료 사용자의 진동은 한 치도 바뀌면 안 된다. 패턴 해석 실패로 진동이 멎는 것.

## 정한 것

1. **표현** — `VibrationPattern` enum (`core/domain`, places·alert·app 이 함께 쓴다 — `AlertSound` 와 같은 자리). 각 값은 박자 목록 `VibrationBeat(onMs, offMs, level)`. `level` 0~1 은 상대 세기.
2. **세기와의 결합** — 파형 = 패턴 × 세기 (`VibrationWaveform.build`, `features/alert/domain`). 진폭 = 세기 진폭 × level (1~255), 떠는 길이 = 박자 길이 × 세기 배율(약 0.8 · 보통 1.0 · 강 1.25). 진폭 제어가 없는 기기는 길이만 반영된다 — #103 과 같은 원칙.
3. **기본 패턴 `standard`** — 지금 동작과 같다: 앱 전면은 `pulseMs` 한 번, 네이티브는 `[400, pulseMs]` 반복. 파형을 만들지 않고 기존 경로를 그대로 탄다.
4. **파형 형식** — Android `createWaveform`·`vibration` 플러그인과 같은 `[쉬기, 떨기, 쉬기, 떨기 …]` ms 목록 + 같은 길이의 세기 목록. 한 형식이 세 경로에 그대로 간다.
5. **경로별**
   - 앱 전면: `VibrationServiceImpl` 이 주기마다 파형 1회(`Vibration.vibrate(pattern:, intensities:)`). 주기 = max(요청 주기 3초, 파형 길이).
   - iOS 화면 없이(시스템 진동): 떨기 칸마다 시스템 진동 1회를 그 시작 시각에 예약 — 시스템 진동은 길이·세기를 못 바꾸므로 **리듬만** 전달된다.
   - Android 감시 서비스: `AlertDecision` 에 `vibrationTimings`·`vibrationAmplitudes` 를 실어 Kotlin 이 `createWaveform(…, repeat=0)`. 비어 있으면 기존 기본 진동.
6. **저장** — 기본 패턴은 SharedPreferences `alert_vibration.pattern`(이름 저장). 장소별은 Drift v4 `alert_places.vibration_pattern` nullable text — null 이면 기본 따름. 기존 장소는 null 로 올라와 동작이 같다.
7. **경계를 건너는 값** — 장소 > `PendingAlert.vibrationPattern`(nullable, 옛 저장값 호환) > `AlertRequest.vibrationPattern` > 컨트롤러가 `장소 값 ?? 기본 패턴` 으로 정한다. 엔진 호스트도 같은 규칙.
8. **무료/프로** — `FeatureAccess.canUseAllVibrationPatterns`. 무료는 `standard` 만 고른다. 다른 패턴은 잠금 흐림 + 프로 안내. **환불돼도 이미 지정한 패턴은 그대로 운다** (알림음 정책과 같다, 결정 075-3). 재생 시점에 등급을 보지 않는다.
9. **고르는 UI** — 공통 시트 `showVibrationPatternSheet` (`features/alert/presentation`). 행 탭 = 고르기 + 한 번 느껴 보기, 하단 "완료" = 확정(닫으면 취소). 잠긴 패턴은 알림음 시트처럼 흐린 묶음이라 눌러도 프로 안내로 간다(빌더 판단: 기존 잠금 방식과 맞춤). 장소 폼은 맨 위에 "기본 설정 따르기" 행이 있고 값을 돌려준다(라우터 배선, places 가 alert 를 import 하지 않는다).
10. **백업** — 파일에 `vibrationPattern` 이름을 넣는다. 없거나 모르는 이름은 null(기본 따름). 백업 schemaVersion 은 그대로 1(선택 필드 추가).
11. **로그** — 세션 시작·엔진 판정에 `pattern=`, 패턴 저장 `[vibration] pattern saved`, 장소 저장 로그에 `vibration=`, 시스템 경로 패턴 재생 실패.

## 패턴 목록 (14)

standard(기본) · doubleTap(톡톡) · tripleTap(톡톡톡) · heartbeat(심장박동) · longShort(길게-짧게) · shortLong(짧게-길게) · sos(SOS) · rapid(연타) · wave(파도) · crescendo(점점 강하게) · knock(노크) · waltz(쿵짝짝) · siren(사이렌) · longPulse(길게 한 번)

## 빌더 몫

- 박자 수치는 손으로 느껴 보고 조정해도 된다 (한 주기 3초 안팎).
- 실기기 검증 필요: 패턴 체감 차이, iOS 시스템 진동 리듬, Android 감시 서비스 파형.
