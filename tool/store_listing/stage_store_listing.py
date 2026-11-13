"""스토어 등록정보 원본(docs/store/descriptions) > fastlane 메타데이터 폴더 (#369)

사용:
  python3 -I tool/store_listing/stage_store_listing.py android <저장소 루트> <android/fastlane/metadata/android>
  python3 -I tool/store_listing/stage_store_listing.py ios <저장소 루트> <ios/fastlane/metadata>
  python3 -I tool/store_listing/stage_store_listing.py check <저장소 루트>   # 글자 수만 검사

글자 수 제한을 넘으면 아무것도 쓰지 않고 1로 끝남 (스토어가 잘라 올리거나 거절하기 전에 막음)
iOS 는 release_notes.txt 가 이미 있는 언어 폴더에만 씀 — 새 언어를 열면 '새 기능' 문구가 비어 심사 제출이 거부됨
"""

import sys
from pathlib import Path

DESCRIPTIONS_DIR = Path("docs/store/descriptions")

# 원본 언어 > 스토어 언어 코드. Play 는 그대로, App Store(deliver) 는 자기 코드만 인정 (ko-KR 무효)
PLAY_LOCALES = {"ko-KR": "ko-KR", "en-US": "en-US", "ja-JP": "ja-JP", "zh-CN": "zh-CN"}
APP_STORE_LOCALES = {"ko-KR": "ko", "en-US": "en-US", "ja-JP": "ja", "zh-CN": "zh-Hans"}

# 칸: (원본 파일 이름 형식, 업로드 파일 이름, 글자 수 제한)
PLAY_FIELDS = [
    ("{locale}_title.txt", "title.txt", 30),
    ("{locale}_short.txt", "short_description.txt", 80),
    ("{locale}_full.txt", "full_description.txt", 4000),
]
APP_STORE_FIELDS = [
    ("ios-{locale}_name.txt", "name.txt", 30),
    ("ios-{locale}_subtitle.txt", "subtitle.txt", 30),
    ("ios-{locale}_keywords.txt", "keywords.txt", 100),
    ("ios-{locale}_promo.txt", "promotional_text.txt", 170),
    ("ios-{locale}_full.txt", "description.txt", 4000),
]


def read_field_text(path: Path) -> str:
    """원본 파일 > 업로드 문자열 (끝 줄바꿈 제거)"""
    return path.read_text(encoding="utf-8").rstrip("\n")


def collect_listing(repo_root: Path, locales: dict, fields: list) -> tuple[list, list]:
    """원본 검사: (업로드 목록 [(스토어 언어, 업로드 파일, 문자열)], 오류 목록)"""
    staged, errors = [], []
    for source_locale, store_locale in locales.items():
        for source_pattern, upload_name, limit in fields:
            source = repo_root / DESCRIPTIONS_DIR / source_pattern.format(locale=source_locale)
            if not source.exists():
                errors.append(f"missing {source.relative_to(repo_root)}")
                continue
            text = read_field_text(source)
            if not text.strip():
                errors.append(f"empty {source.name}")
            elif len(text) > limit:
                errors.append(f"too long {source.name} {len(text)}/{limit}")
            else:
                staged.append((store_locale, upload_name, text))
    return staged, errors


def write_listing(output_dir: Path, staged: list, requires_release_notes: bool) -> None:
    """업로드 폴더에 쓰기. iOS 는 release_notes.txt 없는 언어를 건너뜀"""
    skipped_locales = set()
    for store_locale, upload_name, text in staged:
        locale_dir = output_dir / store_locale
        if requires_release_notes and not (locale_dir / "release_notes.txt").exists():
            skipped_locales.add(store_locale)
            continue
        locale_dir.mkdir(parents=True, exist_ok=True)
        (locale_dir / upload_name).write_text(text, encoding="utf-8")
    written = sorted({locale for locale, _, _ in staged} - skipped_locales)
    print(f"[store listing] staged locales={','.join(written)} dir={output_dir}")
    for locale in sorted(skipped_locales):
        print(f"[store listing] skipped locale={locale} reason=no_release_notes")


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in ("android", "ios", "check"):
        print(__doc__)
        return 2
    mode, repo_root = sys.argv[1], Path(sys.argv[2])

    targets = {
        "android": [(PLAY_LOCALES, PLAY_FIELDS)],
        "ios": [(APP_STORE_LOCALES, APP_STORE_FIELDS)],
        "check": [(PLAY_LOCALES, PLAY_FIELDS), (APP_STORE_LOCALES, APP_STORE_FIELDS)],
    }[mode]

    # 검사 (전부 통과해야 씀)
    staged, errors = [], []
    for locales, fields in targets:
        target_staged, target_errors = collect_listing(repo_root, locales, fields)
        staged += target_staged
        errors += target_errors
    if errors:
        for error in errors:
            print(f"[store listing] rejected {error}")
        return 1
    if mode == "check":
        print(f"[store listing] check passed fields={len(staged)}")
        return 0

    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    write_listing(Path(sys.argv[3]), staged, requires_release_notes=(mode == "ios"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
