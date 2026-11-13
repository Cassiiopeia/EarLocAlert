# -*- coding: utf-8 -*-
"""소개 사이트 공통 원본: 주소·도메인 스위치·스토어 링크·언어 목록·페이지 경로 규칙
언어별 문구는 _src/copy/{언어}.json (랜딩) · _src/copy/guides.{언어}.json (정보 글)
"""

import json
import os

COPY_DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "copy")

# 사이트 주소: github.io(지금) <-> 보유 도메인(이전 후)
GITHUB_PAGES_SITE_URL = "https://cassiiopeia.github.io/EarLocAlert/"
CUSTOM_DOMAIN_HOST = "earlocalert.suhsaechan.kr"
CUSTOM_DOMAIN_SITE_URL = f"https://{CUSTOM_DOMAIN_HOST}/"
# GitHub Pages 를 보유 도메인으로 서빙할 때만 True (CNAME 생성). 시놀로지 서빙은 --custom-domain 으로 별도 빌드
IS_CUSTOM_DOMAIN_ACTIVE = False

SITE_URL = CUSTOM_DOMAIN_SITE_URL if IS_CUSTOM_DOMAIN_ACTIVE else GITHUB_PAGES_SITE_URL
# 404 처럼 어느 깊이에서나 열리는 페이지의 절대 루트 경로
SITE_ROOT_PATH = "/" if IS_CUSTOM_DOMAIN_ACTIVE else "/EarLocAlert/"


def use_custom_domain():
    """--custom-domain 빌드: 이후 생성되는 모든 주소를 보유 도메인 기준으로"""
    global SITE_URL, SITE_ROOT_PATH
    SITE_URL = CUSTOM_DOMAIN_SITE_URL
    SITE_ROOT_PATH = "/"


# 스토어
APP_STORE_APP_ID = "6755805664"
PLAY_PACKAGE_NAME = "kr.suhsaechan.ear_loc_alert"
CONTACT_EMAIL = "chan4760@gmail.com"
DEVELOPER_NAME = "서새찬"
# AdMob 앱 인증: 개발자 웹사이트 도메인 루트에서 읽음 (docs/10-DECISIONS.md app-ads.txt 호스팅)
APP_ADS_TEXT = "google.com, pub-2025665624324395, DIRECT, f08c47fec0942fa0\n"

# 언어 4개: 코드, html lang, og:locale, 랜딩 경로, 정보 글 경로 접두어, 법적 페이지 접미어
LANGUAGES = {
    "ko": {"html_lang": "ko", "og_locale": "ko_KR", "home_path": "", "guide_prefix": "", "legal_suffix": "", "app_store_region": "kr", "label": "한국어"},
    "en": {"html_lang": "en", "og_locale": "en_US", "home_path": "en.html", "guide_prefix": "en/", "legal_suffix": "-en", "app_store_region": "us", "label": "English"},
    "ja": {"html_lang": "ja", "og_locale": "ja_JP", "home_path": "ja.html", "guide_prefix": "ja/", "legal_suffix": "-en", "app_store_region": "jp", "label": "日本語"},
    "zh": {"html_lang": "zh-Hans", "og_locale": "zh_CN", "home_path": "zh.html", "guide_prefix": "zh/", "legal_suffix": "-en", "app_store_region": "cn", "label": "中文"},
}
LANGUAGE_CODES = list(LANGUAGES)
DEFAULT_LANGUAGE_CODE = "ko"
# 법적 페이지 원본이 있는 언어 (ja·zh 는 영어본으로 연결)
LEGAL_SOURCE_LANGUAGE_CODES = ["ko", "en"]
LEGAL_PAGE_NAMES = ["privacy", "terms"]

# 정보 글 slug (언어 공통 > hreflang 으로 서로 연결)
GUIDE_SLUGS = ["bus-stop-alarm", "shuttle-bus-stop-alert", "subway-station-alarm", "silent-alarm-library"]
# 정보 글 공개일·갱신일 (Article JSON-LD)
GUIDE_PUBLISHED_DATE = "2026-11-13"


def app_store_url(language_code):
    return f"https://apps.apple.com/{LANGUAGES[language_code]['app_store_region']}/app/id{APP_STORE_APP_ID}"


def play_store_url(language_code):
    return f"https://play.google.com/store/apps/details?id={PLAY_PACKAGE_NAME}&hl={language_code}"


def home_path(language_code):
    return LANGUAGES[language_code]["home_path"]


def guide_index_path(language_code):
    return LANGUAGES[language_code]["guide_prefix"] + "guide/"


def guide_path(language_code, slug):
    return guide_index_path(language_code) + slug + "/"


def legal_path(language_code, page_name):
    """privacy·terms 경로 (ja·zh > 영어본)"""
    return page_name + LANGUAGES[language_code]["legal_suffix"] + ".html"


def relative_root(page_path):
    """페이지 경로 > 사이트 루트까지 상대 경로 ('' > '', 'guide/x/' > '../../')"""
    directory_depth = page_path.count("/")
    return "../" * directory_depth


def load_home_copy(language_code):
    with open(os.path.join(COPY_DIRECTORY, f"{language_code}.json"), encoding="utf-8") as file:
        return json.load(file)


def load_guide_copy(language_code):
    with open(os.path.join(COPY_DIRECTORY, f"guides.{language_code}.json"), encoding="utf-8") as file:
        return json.load(file)
