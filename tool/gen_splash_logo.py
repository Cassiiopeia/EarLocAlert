"""스플래시 로고 생성 — assets/splash/*.png (이슈 #150)

**앱 아이콘에서 파생시킨다.** 스플래시 로고를 손으로 따로 관리하면
아이콘을 바꿨을 때 따라 바뀌지 않는다 — 실제로 #65 에서 만든 앰버 핀이
아이콘이 시안 핀으로 교체된 뒤에도 두 달 가까이 그대로 남아 있었다.
이 스크립트가 있는 한 아이콘을 바꾸고 다시 돌리면 둘이 어긋나지 않는다.

입력은 `assets/icon/app_icon_foreground.png` (배경이 투명한 핀)이다.
아이콘 본체(`app_icon.png`)에는 남색 배경이 박혀 있어 스플래시 배경색
위에 얹으면 네모가 비친다.

판 크기와 여백은 flutter_native_splash 의 요구를 따른다:

- `splash_logo.png` (768) — Android 11 이하 · iOS. 마스크가 없다.
- `splash_logo_a12.png` (1152) — **Android 12+ 는 원형 마스크가 걸린다.**
  가운데 지름 2/3 만 보이므로 여백을 훨씬 넓게 둔다. 이 판을 따로
  두지 않으면 핀의 위아래가 잘린다.

내용 비율은 교체 전 판과 같게 맞춘다. 크기까지 같이 바뀌면 이번 변경이
"로고 교체"인지 "크기 조정"인지 구분이 안 된다.

사용: python3 tool/gen_splash_logo.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets' / 'icon' / 'app_icon_foreground.png'
OUT_DIR = ROOT / 'assets' / 'splash'

# (파일명, 판 한 변, 내용 높이가 판에서 차지하는 비율)
# 비율은 교체 전 판에서 실측한 값이다 — 768 판 468px, 1152 판 386px
TARGETS = [
    ('splash_logo.png', 768, 0.609),
    ('splash_logo_a12.png', 1152, 0.335),
]


def render(canvas_size: int, height_ratio: float) -> Image.Image:
    """투명 판 가운데에 핀을 얹는다."""
    source = Image.open(SOURCE).convert('RGBA')

    # 알파 기준 실제 내용 영역만 잘라낸다. 원본 판의 여백은 아이콘 마스크용이라
    # 스플래시 여백과 기준이 다르다 — 그대로 축소하면 핀이 작아진다
    box = source.split()[3].getbbox()
    if box is None:
        raise SystemExit(f'내용이 없다: {SOURCE}')
    pin = source.crop(box)

    target_height = round(canvas_size * height_ratio)
    scale = target_height / pin.height
    pin = pin.resize(
        (max(1, round(pin.width * scale)), target_height),
        Image.LANCZOS,
    )

    canvas = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        pin,
        ((canvas_size - pin.width) // 2, (canvas_size - pin.height) // 2),
    )
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, size, ratio in TARGETS:
        image = render(size, ratio)
        path = OUT_DIR / name
        image.save(path)
        box = image.split()[3].getbbox()
        print(f'{name}: {size}x{size} 판, 내용 {box[2] - box[0]}x{box[3] - box[1]}')

    print('\n다음: dart run flutter_native_splash:create')


if __name__ == '__main__':
    main()
