#!/usr/bin/env bash
# 릴리스 노트를 스토어 한도에 맞춰 잘라낸다 (제자리 수정).
#
# 왜 필요한가 — 스토어마다 릴리스 노트 한도가 다르다.
#   Google Play  : 500자
#   App Store    : 4000자
#   Firebase     : 바이트 기준 제한
# 한도를 넘기면 업로드가 통째로 거부된다. 빌드를 다 끝내놓고 노트 길이 때문에
# 실패하는 것이 가장 아까우므로, 올리기 직전에 무조건 줄여서 통과시킨다.
#
# 사용법:
#   truncate_release_notes.sh <파일> <한도> <char|byte>
#
# **문자 세기는 python3 에 맡긴다.** `wc -m` 은 로케일에 따라 한글을 세지
# 못하고 0 을 돌려주는 환경이 있다. 그러면 "한도 이하"로 오판해 자르지 않고
# 넘겨서, 정작 스토어에서 거부당한다. 워크플로우가 이미 python3 를 쓰므로
# 의존성이 늘지도 않는다.
#
# project-auto-wizard v0.1.18 의 워크플로우가 이 스크립트를 호출하는데
# 패키지에 포함돼 있지 않다 (Twin-Fang/project-auto-wizard#43).
# 워크플로우를 고치는 대신 스크립트를 채워 넣는 쪽을 택했다 — 재통합 때
# 워크플로우가 덮어써져도 이 파일은 남기 때문이다.

set -euo pipefail

FILE="${1:-}"
LIMIT="${2:-}"
MODE="${3:-char}"

if [ -z "$FILE" ] || [ -z "$LIMIT" ]; then
  echo "사용법: $0 <파일> <한도> <char|byte>" >&2
  exit 1
fi

case "$MODE" in
  char|byte) ;;
  *) echo "알 수 없는 모드: $MODE (char|byte)" >&2; exit 1 ;;
esac

# 파일이 없으면 조용히 끝낸다 — 노트가 없는 것은 배포를 막을 이유가 아니다
if [ ! -f "$FILE" ]; then
  echo "truncate_release_notes: '$FILE' 없음 — 건너뜀"
  exit 0
fi

# 있는지만 보지 않고 실제로 도는지 확인한다 — Windows 의 python3 처럼
# 이름만 있고 아무것도 하지 않는 스텁이 존재한다.
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
    PY="$c"; break
  fi
done

if [ -n "$PY" ]; then
  "$PY" - "$FILE" "$LIMIT" "$MODE" <<'PYEOF'
import io, sys

# 콘솔 인코딩이 UTF-8 이 아니면 안내 문구 출력만으로 죽는다.
# 릴리스 노트 헬퍼가 배포를 멈추는 일은 없어야 한다.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

path, limit, mode = sys.argv[1], int(sys.argv[2]), sys.argv[3]

with io.open(path, "rb") as fh:
    raw = fh.read()
# 깨진 바이트가 있어도 죽지 않는다 — 노트 때문에 배포가 멈추면 안 된다
text = raw.decode("utf-8", errors="replace")

current = len(text) if mode == "char" else len(raw)
if current <= limit:
    print("truncate_release_notes: %d%s <= %d — 자르지 않음" % (current, mode, limit))
    raise SystemExit(0)

# 잘렸다는 사실이 보여야 사용자가 전체 노트를 어디서 볼지 안다
suffix = "\n…"
room = max(limit - 8, 1)

if mode == "char":
    out = text[:room] + suffix
else:
    # 바이트 한도 — 멀티바이트 문자를 반토막 내지 않도록 뒤에서 줄인다
    cut = room
    while cut > 0:
        chunk = text.encode("utf-8")[:cut]
        try:
            chunk.decode("utf-8")
            break
        except UnicodeDecodeError:
            cut -= 1
    out = chunk.decode("utf-8") + suffix

with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(out)

after = len(out) if mode == "char" else len(out.encode("utf-8"))
print("truncate_release_notes: %d%s → %d%s (한도 %d)" % (current, mode, after, mode, limit))
PYEOF
  exit 0
fi

# ── python3 가 없는 환경 폴백 ────────────────────────────────────────
# 바이트 기준으로만 판단한다. char 모드에서도 바이트로 재는 셈이라
# 필요보다 일찍 자를 수 있지만, 한도를 넘겨 거부당하는 것보다 낫다.
echo "truncate_release_notes: python 없음 — 바이트 기준 폴백" >&2
CURRENT=$(wc -c < "$FILE" | tr -d '[:space:]')
if [ "$CURRENT" -le "$LIMIT" ]; then
  echo "truncate_release_notes: ${CURRENT}byte <= ${LIMIT} — 자르지 않음"
  exit 0
fi
ROOM=$((LIMIT - 8)); [ "$ROOM" -lt 1 ] && ROOM=1
TMP="${FILE}.truncated"
head -c "$ROOM" "$FILE" | iconv -f UTF-8 -t UTF-8 -c > "$TMP" 2>/dev/null \
  || head -c "$ROOM" "$FILE" > "$TMP"
printf '\n…\n' >> "$TMP"
mv "$TMP" "$FILE"
echo "truncate_release_notes: ${CURRENT}byte → $(wc -c < "$FILE" | tr -d '[:space:]')byte (한도 ${LIMIT})"
