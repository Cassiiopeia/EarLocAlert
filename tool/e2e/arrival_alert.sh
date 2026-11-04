#!/usr/bin/env bash
# 도착 알림 e2e (Android 에뮬레이터, #345): 환경 조작 + 로그 판정
#
# 사용:
#   tool/e2e/arrival_alert.sh prepare <debug apk>   설치 > 권한 > 대기 위치(장소 밖)
#   tool/e2e/arrival_alert.sh run <시나리오>          screen_off | process_killed | db_locked
#   tool/e2e/arrival_alert.sh all                    필수 시나리오 3개를 순서대로
#
# 장소 등록은 화면 조작이라 고정하지 않는다 > flows/add_place.yaml 을 Maestro 로 돌리거나 agent 가 직접 등록
# 결과: 표준 출력 + build/e2e/arrival_alert_{UTC}.md (실패 시 종료 코드 1)
set -uo pipefail

PACKAGE="kr.suhsaechan.ear_loc_alert"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"
PLACE_NAME="${E2E_PLACE_NAME:-E2E Arrival}"
# 장소 중심 (flows/add_place.yaml 과 같은 값)
PLACE_LAT="37.5665"
PLACE_LNG="126.9780"
# 대기 위치: 북쪽 10걸음 (150m x 10 = 1.5km, 근접 구간 안이라 정밀 추적이 돈다)
STEP_LAT_DEGREES="0.00135"
STEP_COUNT=10
# 걸음 간격 (6초 x 150m = 90km/h, 위치 튐 임계 300km/h 아래)
STEP_SECONDS=6
# 발화 판정 대기 상한
FIRE_TIMEOUT_SECONDS=90
# DB 잠금 유지 (busy_timeout 5초 + 판정 재시도 3회 안에서 풀리는 길이)
DB_LOCK_SECONDS=8

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/build/e2e"
REPORT_FILE="$REPORT_DIR/arrival_alert_$(date -u +%Y%m%dT%H%M%SZ).md"
FAILED=0

adb_device() { adb -s "$DEVICE" "$@"; }
device_now() { adb_device shell date -u +%Y-%m-%dT%H:%M:%S | tr -d '\r'; }

# 앱 진단 로그 읽기: diagnostic.log(네이티브) · diagnostic.bg.log(감시 엔진) · diagnostic.app.log(화면)
read_log_since() {
  local file_name="$1" since="$2"
  adb_device shell "run-as $PACKAGE cat files/$file_name" 2>/dev/null | tr -d '\r' | awk -v since="$since" '$1 >= since'
}

# 패턴이 나올 때까지 대기 (찾으면 0, 시간 초과 1)
wait_for_log() {
  local file_name="$1" pattern="$2" since="$3" timeout_seconds="$4"
  local waited=0
  while [ "$waited" -lt "$timeout_seconds" ]; do
    if read_log_since "$file_name" "$since" | grep -qE "$pattern"; then return 0; fi
    sleep 3; waited=$((waited + 3))
  done
  return 1
}

# 위치 고정: 중심에서 북쪽으로 step 걸음 (geo fix 는 경도 먼저)
set_position_step() {
  local step="$1"
  local latitude
  latitude=$(python3 -c "print(round($PLACE_LAT + $STEP_LAT_DEGREES * $step, 6))")
  adb_device emu geo fix "$PLACE_LNG" "$latitude" >/dev/null
}

# 대기 위치 > 장소 중심 (stop_before 걸음에서 멈춤: DB 잠금 주입용)
walk_in() {
  local stop_before="${1:-0}"
  local step
  for step in $(seq "$STEP_COUNT" -1 "$stop_before"); do
    set_position_step "$step"; sleep "$STEP_SECONDS"
  done
}

# 장소 중심 > 대기 위치 (다음 시나리오가 다시 밖에서 시작하도록)
walk_out() {
  local step
  for step in $(seq 1 "$STEP_COUNT"); do
    set_position_step "$step"; sleep "$STEP_SECONDS"
  done
  sleep 20
}

send_screen_off() {
  adb_device shell input keyevent KEYCODE_HOME
  sleep 2
  adb_device shell input keyevent KEYCODE_SLEEP
  sleep 3
}

# 화면의 "알림 끄기" 요소를 찾아 누름 (요소 기준, 좌표 하드코딩 없음)
dismiss_alert() {
  adb_device shell input keyevent KEYCODE_WAKEUP
  adb_device shell uiautomator dump /sdcard/e2e_window.xml >/dev/null 2>&1
  local center
  center=$(adb_device shell cat /sdcard/e2e_window.xml | python3 -c '
import re, sys
xml = sys.stdin.read()
match = re.search(r"(?:content-desc|text)=\"(?:Dismiss|알림 끄기)\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", xml)
if match:
    left, top, right, bottom = map(int, match.groups())
    print((left + right) // 2, (top + bottom) // 2)
')
  if [ -z "$center" ]; then
    echo "[e2e] dismiss button not found"
    return 1
  fi
  # shellcheck disable=SC2086
  adb_device shell input tap $center
}

record_result() {
  local scenario="$1" check="$2" result="$3" evidence="$4"
  echo "| $scenario | $check | $result | $evidence |" | tee -a "$REPORT_FILE"
  if [ "$result" = "FAIL" ]; then FAILED=1; fi
}

# 판정 4단계: 엔진 결정 > 네이티브 발화 > 화면 승격 > 상태바 알림
assert_alert_fired() {
  local scenario="$1" since="$2"
  local place_pattern="name=$PLACE_NAME"
  if wait_for_log diagnostic.bg.log "decision .*$place_pattern transition=entered -> alert" "$since" "$FIRE_TIMEOUT_SECONDS"; then
    record_result "$scenario" "engine decision" PASS "decision -> alert"
  else
    local last_decision
    last_decision=$(read_log_since diagnostic.bg.log "$since" | grep -E "decision" | tail -1 | cut -c1-160)
    record_result "$scenario" "engine decision" FAIL "last: ${last_decision:-none}"
  fi
  if wait_for_log diagnostic.log "alert started place=$PLACE_NAME" "$since" 15; then
    record_result "$scenario" "native fire" PASS "alert started"
  else
    record_result "$scenario" "native fire" FAIL "no alert started"
  fi
  if wait_for_log diagnostic.app.log "alert session promoted place=$PLACE_NAME" "$since" 30; then
    record_result "$scenario" "alert screen" PASS "session promoted"
  else
    record_result "$scenario" "alert screen" FAIL "no session promoted"
  fi
  if adb_device shell dumpsys notification --noredact | grep -q "pkg=$PACKAGE.*channel=ear_loc_alert_session"; then
    record_result "$scenario" "status bar notification" PASS "channel=ear_loc_alert_session"
  else
    record_result "$scenario" "status bar notification" FAIL "no session notification"
  fi
}

# 끄기 > 해제 확인 > 대기 위치 복귀
reset_after_scenario() {
  local scenario="$1" since="$2"
  dismiss_alert
  if wait_for_log diagnostic.app.log "session dismissed place=$PLACE_NAME" "$since" 20; then
    record_result "$scenario" "dismiss" PASS "session dismissed"
  else
    record_result "$scenario" "dismiss" FAIL "no session dismissed"
  fi
  walk_out
}

run_screen_off() {
  local since; since=$(device_now)
  send_screen_off
  walk_in
  assert_alert_fired screen_off "$since"
  reset_after_scenario screen_off "$since"
}

# 앱 프로세스 강제 종료 (메모리 부족·크래시와 같은 종료) 후 감시 복구 확인
run_process_killed() {
  local since; since=$(device_now)
  send_screen_off
  local process_id
  process_id=$(adb_device shell pidof "$PACKAGE" | tr -d '\r')
  if [ -n "$process_id" ]; then
    adb_device shell "run-as $PACKAGE kill -9 $process_id"
    record_result process_killed "process kill" PASS "killed pid=$process_id"
  else
    record_result process_killed "process kill" FAIL "app process not running"
  fi
  sleep 15
  walk_in
  assert_alert_fired process_killed "$since"
  reset_after_scenario process_killed "$since"
}

# 마지막 걸음 직전에 DB 쓰기 잠금 > 잠긴 동안 진입
run_db_locked() {
  local since; since=$(device_now)
  send_screen_off
  walk_in 1
  adb_device shell am broadcast -n "$PACKAGE/.E2eDatabaseLockReceiver" --ei seconds "$DB_LOCK_SECONDS" >/dev/null
  set_position_step 0
  if wait_for_log diagnostic.log "db lock held seconds=$DB_LOCK_SECONDS" "$since" 10; then
    record_result db_locked "lock injected" PASS "held ${DB_LOCK_SECONDS}s"
  else
    record_result db_locked "lock injected" FAIL "debug receiver missing (release build?)"
  fi
  assert_alert_fired db_locked "$since"
  local retry_count
  retry_count=$(read_log_since diagnostic.bg.log "$since" | grep -c "decision retry reason=db_locked")
  record_result db_locked "lock retries (info)" INFO "retries=$retry_count"
  # 주입이 DB 를 깨뜨리면 이후 결과는 무의미 > 앱을 지우고 다시 준비해야 함
  if read_log_since diagnostic.bg.log "$since" | grep -q "database disk image is malformed"; then
    record_result db_locked "database intact" FAIL "malformed after injection, reinstall the app"
  else
    record_result db_locked "database intact" PASS "no malformed error"
  fi
  reset_after_scenario db_locked "$since"
}

# 설치 > 권한 6종 > 절전 예외 > 대기 위치
prepare_device() {
  local apk_path="$1"
  # 덮어쓰기는 옛·새 APK 가 함께 있을 공간이 필요 > 모자라면 지우고 새로 (장소는 다시 등록)
  if ! adb_device install -r "$apk_path"; then
    echo "[e2e] replace install failed, reinstalling clean (places are removed)"
    adb_device uninstall "$PACKAGE" >/dev/null
    adb_device install "$apk_path" || { echo "[e2e] install failed"; exit 1; }
  fi
  local permission
  for permission in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACCESS_BACKGROUND_LOCATION POST_NOTIFICATIONS; do
    adb_device shell pm grant "$PACKAGE" "android.permission.$permission"
  done
  adb_device shell appops set "$PACKAGE" SYSTEM_ALERT_WINDOW allow
  adb_device shell appops set "$PACKAGE" USE_FULL_SCREEN_INTENT allow
  adb_device shell dumpsys deviceidle whitelist "+$PACKAGE" >/dev/null
  adb_device shell settings put secure location_mode 3
  set_position_step "$STEP_COUNT"
  echo "[e2e] prepared. next: register place \"$PLACE_NAME\" ($PLACE_LAT,$PLACE_LNG) via flows/add_place.yaml"
}

start_report() {
  mkdir -p "$REPORT_DIR"
  {
    echo "# 도착 알림 e2e $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "device=$DEVICE app=$(adb_device shell dumpsys package "$PACKAGE" | grep -m1 versionName | tr -d ' \r')"
    echo
    echo "| 시나리오 | 확인 | 결과 | 근거 |"
    echo "|---|---|---|---|"
  } > "$REPORT_FILE"
  cat "$REPORT_FILE"
}

run_scenario() {
  case "$1" in
    screen_off) run_screen_off ;;
    process_killed) run_process_killed ;;
    db_locked) run_db_locked ;;
    *) echo "unknown scenario: $1 (screen_off | process_killed | db_locked)"; exit 2 ;;
  esac
}

case "${1:-}" in
  prepare) prepare_device "${2:?debug apk path}" ;;
  run) start_report; run_scenario "${2:?scenario}" ;;
  all) start_report; run_scenario screen_off; run_scenario process_killed; run_scenario db_locked ;;
  *) sed -n 2,9p "$0"; exit 2 ;;
esac

if [ "${1:-}" != "prepare" ]; then
  echo; echo "report: $REPORT_FILE"
  exit "$FAILED"
fi
