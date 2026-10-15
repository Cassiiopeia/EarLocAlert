"""스토어 홍보 이미지 생성기 (#281)

원본 화면 캡처 + scenes.json 의 문구로 스토어 규격 이미지를 만든다.

    python3 -I tool/store_art/render.py --platform ios --lang ko --shots <원본 폴더> [--banner-top 2271]
    python3 -I tool/store_art/render.py --wide og --lang ko --shots <원본 폴더>

- Chrome 헤드리스로 정확한 픽셀 크기로 찍는다. 글꼴은 레포의 Pretendard.
- 디버그 빌드 캡처의 하단 AdMob 테스트 배너는 --banner-top 아래를 검정으로 덮는다.
- 결과는 scenes.json 의 targets.<platform>.out 에 `<id>.png` 로 저장한다.
"""

import argparse
import html
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def prepare_shot(src: Path, dst: Path, banner_top: int | None) -> float:
    """배너를 덮은 사본을 만들고 화면 비율(가로/세로)을 돌려준다."""
    image = Image.open(src).convert("RGB")
    if banner_top is not None:
        # 배너 바로 위 화면 바탕색으로 덮음 (라이트 화면에 검은 띠 방지)
        background = image.getpixel((8, banner_top - 12))
        ImageDraw.Draw(image).rectangle(
            [0, banner_top - 3, image.width, image.height], fill=background
        )
    image.save(dst)
    return image.width / image.height


def render_scene(target: dict, scene: dict, lang: str, platform: str, shot: Path, aspect: float, out: Path) -> None:
    template = (HERE / "template.html").read_text(encoding="utf-8")
    # 문구는 언어별 사전에서 고른다 — 없는 언어면 영어로 떨어진다
    pick = lambda field: scene[field].get(lang) or scene[field]["en"]
    eyebrow = pick("eyebrow")
    values = {
        "lang": lang,
        "width": str(target["width"]),
        "height": str(target["height"]),
        "font_dir": (ROOT / "assets/fonts/pretendard").as_uri(),
        "shot": shot.as_uri(),
        "shot_aspect": f"{aspect:.6f}",
        # 문구는 scenes.json 에서 오는 신뢰된 값이다 — <br>·<em> 강조를 그대로 쓴다
        "headline": pick("headline"),
        # iOS 는 알림 방식이 달라 문구를 따로 둘 수 있다 (sub_ios)
        "sub": html.escape(pick("sub_ios") if platform == "ios" and "sub_ios" in scene else pick("sub")),
        "eyebrow_html": f'<div class="eyebrow">{html.escape(eyebrow)}</div>' if eyebrow else "",
    }
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)

    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as page:
        page.write(template)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--window-size={target['width']},{target['height']}",
            # 글꼴·이미지가 다 그려질 시간을 준다 — 너무 짧으면 기본 글꼴로 찍힌다
            "--virtual-time-budget=3000",
            "--allow-file-access-from-files",
            f"--screenshot={out}",
            Path(page.name).as_uri(),
        ],
        check=True,
        capture_output=True,
    )
    size = Image.open(out).size
    if size != (target["width"], target["height"]):
        sys.exit(f"규격이 다르다: {out} {size}")


WIDE_TARGETS = {
    # Play Console 그래픽 이미지 — 배지·가격 문구를 넣지 않는다 (docs/store/README.md)
    "feature": {"width": 1024, "height": 500, "out": "docs/store/promo/{lang}/feature-graphic.png"},
    # 링크를 공유할 때 뜨는 미리보기 (소개 페이지 og:image)
    "og": {"width": 1200, "height": 630, "out": "docs/store/promo/{lang}/og.png"},
}


def render_wide(kind: str, lang: str, wide: dict, shots: Path, front: str, back: str, banner_top: int | None) -> None:
    """가로형 이미지 — 왼쪽 문구, 오른쪽 휴대폰 두 대."""
    target = WIDE_TARGETS[kind]
    work = Path(tempfile.mkdtemp())
    front_shot, back_shot = work / "front.png", work / "back.png"
    aspect = prepare_shot(shots / front, front_shot, None)
    prepare_shot(shots / back, back_shot, banner_top)
    template = (HERE / "wide_template.html").read_text(encoding="utf-8")
    values = {
        "lang": lang, "width": str(target["width"]), "height": str(target["height"]),
        "font_dir": (ROOT / "assets/fonts/pretendard").as_uri(),
        "logo": (ROOT / "assets/icon/app_logo_mark.png").as_uri(),
        "app_name": html.escape(wide["app_name"][lang]),
        "headline": wide["headline"][lang],
        "sub": html.escape(wide["sub"][lang]),
        "shot_front": front_shot.as_uri(), "shot_back": back_shot.as_uri(),
        "shot_aspect": f"{aspect:.6f}",
    }
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as page:
        page.write(template)
    out = ROOT / target["out"].format(lang=lang)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=1", f"--window-size={target['width']},{target['height']}",
         "--virtual-time-budget=3000", "--allow-file-access-from-files",
         f"--screenshot={out}", Path(page.name).as_uri()],
        check=True, capture_output=True,
    )
    print(f"만듦 {out.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wide", choices=list(WIDE_TARGETS), help="가로형 이미지만 만든다")
    parser.add_argument("--lang", choices=["ko", "en", "ja", "zh"], default="ko", help="문구 언어")
    parser.add_argument("--front", default="01_alert_dark.png", help="가로형 앞 화면")
    parser.add_argument("--back", default="04_home_dark.png", help="가로형 뒤 화면")
    parser.add_argument("--platform", choices=["ios", "android"])
    parser.add_argument("--shots", type=Path, required=True, help="원본 화면 캡처 폴더")
    parser.add_argument("--banner-top", type=int, default=None, help="테스트 광고 배너 윗변 y(원본 픽셀). adBanner 인 장면에만 쓴다")
    args = parser.parse_args()

    config = json.loads((HERE / "scenes.json").read_text(encoding="utf-8"))
    if args.wide:
        render_wide(args.wide, args.lang, config["wide"], args.shots, args.front, args.back, args.banner_top)
        return
    if args.platform is None:
        parser.error("--platform 또는 --wide 중 하나가 필요하다")

    target = config["targets"][args.platform]
    work = Path(tempfile.mkdtemp())
    for scene in config["scenes"]:
        src = args.shots / scene["shot"]
        if not src.exists():
            print(f"건너뜀 — 원본 없음: {src}")
            continue
        shot = work / scene["shot"]
        # 배너는 홈·폼·설정처럼 하단에 광고 자리가 있는 화면에만 있다
        banner = args.banner_top if scene.get("adBanner") else None
        aspect = prepare_shot(src, shot, banner)
        out = ROOT / target["out"].format(lang=args.lang) / f"{scene['id']}.png"
        render_scene(target, scene, args.lang, args.platform, shot, aspect, out)
        print(f"만듦 {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
