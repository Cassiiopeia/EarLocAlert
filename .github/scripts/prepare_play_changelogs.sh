#!/usr/bin/env bash
# Play 릴리스 노트를 언어별로 준비한다 (이슈 #167).
#
# 왜 스크립트인가 — 배포 워크플로우는 템플릿이 관리해 이 저장소에서 고치면
# 다음 갱신에 덮인다. 로직을 스크립트에 두면 워크플로우가 덮여도 남는다
# (truncate_release_notes.sh 와 같은 이유).
#
# 동작
#   - 한국어(ko-KR) 노트는 워크플로우가 이미 만들어 둔다. 그것을 원본으로 쓴다.
#   - 나머지 언어(en-US, ja-JP, zh-CN)는 언어별 파일이 있으면 그것을,
#     없으면 한국어 노트를 그대로 올린다. 빈 화면보다 낫다.
#   - 언어별 파일 위치: release-notes/<언어>/<버전>.txt (예: release-notes/en-US/1.19.0.txt)
#
# 사용법: prepare_play_changelogs.sh <워크스페이스> <버전 이름> <버전 코드>

set -euo pipefail

WORKSPACE="${1:-}"
VERSION_NAME="${2:-}"
VERSION_CODE="${3:-}"

if [ -z "$WORKSPACE" ] || [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ]; then
  echo "사용법: $0 <워크스페이스> <버전 이름> <버전 코드>" >&2
  exit 1
fi

BASE="$WORKSPACE/android/fastlane/metadata/android"
KO_NOTES="$BASE/ko-KR/changelogs/${VERSION_CODE}.txt"

if [ ! -s "$KO_NOTES" ]; then
  # 원본이 없으면 다른 언어를 만들 수 없다. 배포를 막을 이유는 아니다
  echo "⚠️ 한국어 릴리스 노트가 없어 다른 언어를 건너뜁니다: $KO_NOTES"
  exit 0
fi

for LANG_DIR in en-US ja-JP zh-CN; do
  TARGET_DIR="$BASE/$LANG_DIR/changelogs"
  TARGET="$TARGET_DIR/${VERSION_CODE}.txt"
  SOURCE="$WORKSPACE/release-notes/$LANG_DIR/${VERSION_NAME}.txt"
  mkdir -p "$TARGET_DIR"

  if [ -s "$SOURCE" ]; then
    cp "$SOURCE" "$TARGET"
    # Play 한도(500자)를 넘기면 업로드가 통째로 거부된다 — 올리기 직전에 무조건 줄인다
    bash "$WORKSPACE/.github/scripts/truncate_release_notes.sh" "$TARGET" 480 char
    echo "✅ $LANG_DIR 릴리스 노트: 언어별 파일 사용"
  else
    cp "$KO_NOTES" "$TARGET"
    echo "ℹ️ $LANG_DIR 릴리스 노트: 언어별 파일이 없어 한국어 노트를 대신 사용"
  fi
done
