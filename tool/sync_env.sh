#!/usr/bin/env bash
#
# .env → iOS 빌드 설정 동기화 (docs/08-OPERATIONS.md)
#
# Android 는 build.gradle.kts 가 .env 를 직접 읽으므로 이 스크립트가 필요 없다.
# iOS 는 xcconfig 를 거쳐야 Info.plist 치환이 되기 때문에 한 단계가 더 있다.
#
#   .env (MAPS_API_KEY) → ios/Flutter/MapsKey.xcconfig → Info.plist → AppDelegate
#
# 사용:
#   ./tool/sync_env.sh          # 레포 루트에서
#
# iOS 빌드 전에 한 번 돌린다. .env 가 없거나 키가 비어 있어도 실패하지 않는다 —
# 지도만 회색으로 뜨고 나머지는 정상 동작한다.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/.env"
target="$root/ios/Flutter/MapsKey.xcconfig"

key=""
if [[ -f "$env_file" ]]; then
  # 주석·빈 줄을 건너뛰고 MAPS_API_KEY 만 꺼낸다
  key="$(grep -E '^[[:space:]]*MAPS_API_KEY[[:space:]]*=' "$env_file" | tail -n 1 | cut -d= -f2- | tr -d '"'"'"' \t\r' || true)"
else
  echo "경고: $env_file 이 없다. 지도 없이 빌드된다." >&2
fi

mkdir -p "$(dirname "$target")"
cat > "$target" <<EOF
// 자동 생성 파일 — 직접 고치지 않는다. tool/sync_env.sh 가 .env 에서 만든다.
MAPS_API_KEY=$key
EOF

if [[ -z "$key" ]]; then
  echo "MAPS_API_KEY 가 비어 있다 — 지도는 회색으로 뜬다."
else
  echo "MapsKey.xcconfig 생성 완료 (키 끝 4자리: ${key: -4})"
fi
