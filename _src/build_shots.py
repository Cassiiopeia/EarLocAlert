# -*- coding: utf-8 -*-
"""언어별 앱 화면 캡처 > 사이트용 JPG (shots/{언어}/{화면}.jpg, 486x1054)
원본: 앱 레포 docs/store/promo/source/ios/{언어}/ (스토어 홍보 이미지와 같은 캡처 > 사이트·스토어 화면 일치)
실행: python3 _src/build_shots.py <앱 레포 경로>   (Pillow 필요, 사이트 빌드와 별개로 캡처를 바꿨을 때만)
"""

import os
import sys

from PIL import Image

SITE_ROOT_DIRECTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGUAGE_CODES = ["ko", "en", "ja", "zh"]
# 사이트 화면 이름 > 원본 파일명
SOURCE_FILE_BY_SHOT_NAME = {
    "alert": "01_alert_dark.png",
    "form": "03_form_dark.png",
    "home": "04_home_dark.png",
    "schedule": "05_schedule_dark.png",
    "settings": "06_settings_light.png",
    "sound": "07_sound_dark.png",
}
# 폰 목업 최대 표시 폭 300px 의 레티나 1.6배 수준 (파일 크기와 선명도 절충)
SHOT_SIZE_PIXELS = (486, 1054)
JPEG_QUALITY = 84
# 원본 캡처의 AdMob 테스트 배너 줄 (486x1054 기준 y 범위) > 아래 하단 여백 색으로 덮음 (사이트에 "Test mode" 노출 방지)
SHOT_NAMES_WITH_TEST_BANNER = {"form", "home", "settings"}
TEST_BANNER_ROW_RANGE = (930, 1016)
BOTTOM_INSET_SAMPLE_POINT = (20, 1034)


def cover_test_banner(image):
    """테스트 광고 배너 줄 > 화면 하단 여백 색 (홈 표시줄 위까지)"""
    inset_color = image.getpixel(BOTTOM_INSET_SAMPLE_POINT)
    top_row, bottom_row = TEST_BANNER_ROW_RANGE
    image.paste(inset_color, (0, top_row, image.width, bottom_row))


def build_shots(app_repository_path):
    source_root = os.path.join(app_repository_path, "docs", "store", "promo", "source", "ios")
    written_count = 0
    for language_code in LANGUAGE_CODES:
        target_directory = os.path.join(SITE_ROOT_DIRECTORY, "shots", language_code)
        os.makedirs(target_directory, exist_ok=True)
        for shot_name, source_file_name in SOURCE_FILE_BY_SHOT_NAME.items():
            source_path = os.path.join(source_root, language_code, source_file_name)
            image = Image.open(source_path).convert("RGB").resize(SHOT_SIZE_PIXELS, Image.LANCZOS)
            if shot_name in SHOT_NAMES_WITH_TEST_BANNER:
                cover_test_banner(image)
            image.save(os.path.join(target_directory, shot_name + ".jpg"), quality=JPEG_QUALITY, optimize=True, progressive=True)
            written_count += 1
    print(f"[site shots] written {written_count} : {', '.join(LANGUAGE_CODES)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 _src/build_shots.py <app repository path>")
    build_shots(sys.argv[1])
