# 도착 알림 e2e (Android 에뮬레이터)

"도착하면 울린다"를 앱 배포 전에 에뮬레이터에서 처음부터 끝까지 확인한다 (#345, 결정 085).

**고정할 것과 agent 가 판단할 것을 나눴다.** 화면이 자주 바뀌는 시기라 화면 조작까지 고정하면 기능이 멀쩡해도 깨진다.

| 구분 | 맡는 것 | 위치 |
|---|---|---|
| 고정 | 위치 이동, 화면 끄기, 프로세스 종료, DB 잠금, 로그·시스템 기록 판정 | `arrival_alert.sh` |
| agent | 장소 등록 같은 화면 조작, 알림 화면 캡처 확인, 실패 원인 찾기, 변경에 맞는 시나리오 추가 | `flows/add_place.yaml` (깨지면 고치거나 직접 등록) |

## 순서

```bash
export PATH="$HOME/development/flutter-3.35.5/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"
flutter build apk --debug                                    # DB 잠금 주입 수신기는 디버그 빌드에만 있다
tool/e2e/arrival_alert.sh prepare build/app/outputs/flutter-apk/app-debug.apk
maestro --device emulator-5554 test tool/e2e/flows/add_place.yaml   # 또는 agent 가 화면으로 등록
tool/e2e/arrival_alert.sh all                                # 시나리오 3개, 약 10분
```

기기는 `ANDROID_SERIAL` 로 고른다 (기본 `emulator-5554`). Google Play 시스템 이미지여야 한다 (위치·지오펜스가 Play 서비스를 쓴다).

## 필수 시나리오

| 시나리오 | 하는 일 | 막으려는 것 |
|---|---|---|
| `screen_off` | 홈으로 내리고 화면 끔 > 걸어서 진입 | 주머니 속 기본 상황 |
| `process_killed` | 앱 프로세스를 kill -9 > 15초 뒤 진입 | 메모리 부족·크래시 뒤 감시가 안 살아나는 것 (#134) |
| `db_locked` | 마지막 걸음 직전 DB 쓰기 잠금 8초 > 잠긴 채 진입 | 판정이 DB 잠금으로 빠지는 것 (#337) |

각 시나리오는 1.5km 밖에서 6초마다 150m 씩 걸어 들어온다 (위치 튐 임계 300km/h 아래). 끝나면 알림을 끄고 다시 걸어 나간다.

## 판정

| 확인 | 근거 로그 |
|---|---|
| 엔진 결정 | `diagnostic.bg.log` `decision ... transition=entered -> alert` |
| 네이티브 발화 | `diagnostic.log` `alert started place=` |
| 알림 화면 | `diagnostic.app.log` `alert session promoted place=` |
| 상태바 알림 | `dumpsys notification` 의 `channel=ear_loc_alert_session` |
| 끄기 | `diagnostic.app.log` `session dismissed place=` |

결과는 화면과 `build/e2e/arrival_alert_{UTC}.md` 에 표로 남고, 하나라도 FAIL 이면 종료 코드 1 이다.

## 에뮬레이터로 못 보는 것

- **앱 진동이 계속 울리는지.** vibration 플러그인이 Android 에서 실물 기기가 아니면 진동기 없음으로 답한다. 에뮬레이터 로그에는 `vibration skipped reason=no_vibrator` 가 남는다. 네이티브 첫 진동은 `dumpsys vibrator_manager` 에 남는다.
- 이어폰 연결, 실제 이동, 제조사 배터리 정책, iOS. 실기기로 확인한다.

## 막히면

- `INSTALL_FAILED_INSUFFICIENT_STORAGE` > `prepare` 가 지우고 새로 설치한다. 그래도 모자라면 테스트와 무관한 구글 앱 업데이트를 되돌린다 (`pm uninstall-system-updates com.google.android.youtube` 등). Play 서비스·WebView 는 건드리지 않는다.
- 진입했는데 `decision` 이 없다 > `diagnostic.bg.log` 에서 `no_alert (reason=...)` 를 본다. `location_jump` 면 이전 위치에서 너무 멀리 한 번에 옮긴 것이다.
