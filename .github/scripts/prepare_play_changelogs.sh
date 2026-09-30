#!/usr/bin/env bash
# Play 릴리스 노트를 언어별로 준비한다 (이슈 #167).
#
# 왜 스크립트인가 — 배포 워크플로우는 템플릿이 관리해 이 저장소에서 고치면
# 다음 갱신에 덮인다. 로직을 스크립트에 두면 워크플로우가 덮여도 남는다
# (truncate_release_notes.sh 와 같은 이유).
#
# 동작
#   - 한국어(ko-KR) 노트는 워크플로우가 CHANGELOG.json(커밋 요약)에서 만들어 둔다.
#     **그 자동 노트에는 커밋 메시지 그대로의 내부 문구(문서 항목, 이슈 번호,
#     "구현 보고서를 남긴다")가 섞여 스토어 사용자에게 보인다** (2026-09-29 Play
#     Console 실측, 1.18.3~1.18.5). 그래서 직접 쓴 파일이 있으면 그것이 우선한다.
#   - 다른 언어(release-notes/ 아래 폴더)도 언어별 파일이 있으면 그것을, 없으면 한국어
#     노트를 그대로 올린다. 빈 화면보다 낫다.
#   - 언어별 파일 위치: release-notes/<언어>/<버전>.txt
#     (예: release-notes/ko-KR/1.19.0.txt, release-notes/en-US/1.19.0.txt)
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

# 직접 쓴 한국어 노트가 있으면 자동 노트를 덮어쓴다 (스토어에 내부 문구가 보이지 않게)
KO_CURATED="$WORKSPACE/release-notes/ko-KR/${VERSION_NAME}.txt"
if [ -s "$KO_CURATED" ]; then
  mkdir -p "$(dirname "$KO_NOTES")"
  cp "$KO_CURATED" "$KO_NOTES"
  bash "$WORKSPACE/.github/scripts/truncate_release_notes.sh" "$KO_NOTES" 480 char
  echo "✅ ko-KR 릴리스 노트: 직접 쓴 파일 사용 (자동 노트를 덮어쓴다)"
else
  echo "ℹ️ ko-KR 릴리스 노트: 직접 쓴 파일이 없어 자동 노트를 그대로 쓴다 — 내부 문구가 섞일 수 있다"
fi

if [ ! -s "$KO_NOTES" ]; then
  # 원본이 없으면 다른 언어를 만들 수 없다. 배포를 막을 이유는 아니다
  echo "⚠️ 한국어 릴리스 노트가 없어 다른 언어를 건너뜁니다: $KO_NOTES"
  exit 0
fi

# 언어 목록은 release-notes/ 아래 폴더가 정한다 — 언어를 늘릴 때 이 스크립트를 고치지 않는다
# (폴더가 빠지지 않는지는 test/core/l10n/language_sync_test.dart 가 지킨다)
for LANG_PATH in "$WORKSPACE"/release-notes/*/; do
  LANG_DIR="$(basename "$LANG_PATH")"
  [ "$LANG_DIR" = "ko-KR" ] && continue
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
