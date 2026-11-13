# -*- coding: utf-8 -*-
"""모든 페이지 공통 틀: head(SEO·hreflang·og) · 상단 메뉴(언어 전환 포함) · 하단 · 스토어 버튼
페이지 정보 page: language, path, title, description, alternates{언어: 경로}, schemas[], og_image, is_indexable, keywords
"""

import json
from html import escape

import site_content as content
from site_icons import APPLE_LOGO, PLAY_LOGO, render_icon

# 정적 자원 캐시 무효화 버전 (style.css·site.js 를 바꾸면 올림)
ASSET_VERSION = "20261113b"
# 웹폰트: 한·영 Pretendard, 일본어 Pretendard JP (중국어는 시스템 글꼴 > 글꼴 파일 수 MB 회피)
FONT_STYLESHEET_URLS = {
    "default": "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css",
    "ja": "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/packages/pretendard-jp/dist/web/variable/pretendardvariable-jp-dynamic-subset.min.css",
}
THEME_COLOR = "#fbfbfd"


def format_inline(text):
    """문구 > 안전한 HTML (escape 후 **굵게** 만 <b> 로)"""
    parts = escape(text).split("**")
    return "".join(f"<b>{part}</b>" if index % 2 else part for index, part in enumerate(parts))


def absolute_url(page_path):
    return content.SITE_URL + page_path


def render_head(page, root):
    language_code = page["language"]
    language = content.LANGUAGES[language_code]
    copy = content.load_home_copy(language_code)
    title, description = escape(page["title"]), escape(page["description"])
    canonical_url = absolute_url(page["path"])
    og_image_url = absolute_url(page.get("og_image") or f"icon/og-{language_code}.png")
    robots_meta = "" if page.get("is_indexable", True) else '\n<meta name="robots" content="noindex">'
    keywords_meta = f'\n<meta name="keywords" content="{escape(page["keywords"])}">' if page.get("keywords") else ""
    alternate_links = render_alternate_links(page.get("alternates", {}))
    font_urls = [FONT_STYLESHEET_URLS["default"]] + ([FONT_STYLESHEET_URLS["ja"]] if language_code == "ja" else [])
    font_links = "\n".join(f'<link rel="stylesheet" href="{url}" crossorigin>' for url in font_urls)
    schema_scripts = "".join(
        f'\n<script type="application/ld+json">{json.dumps(schema, ensure_ascii=False)}</script>'
        for schema in page.get("schemas", [])
    )
    return f"""<!DOCTYPE html>
<html lang="{language['html_lang']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{description}">{keywords_meta}{robots_meta}
<link rel="canonical" href="{canonical_url}">{alternate_links}
<meta property="og:site_name" content="{escape(copy['meta']['app_name'])}">
<meta property="og:locale" content="{language['og_locale']}">
<meta property="og:type" content="{page.get('og_type', 'website')}">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{canonical_url}">
<meta property="og:image" content="{og_image_url}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="apple-itunes-app" content="app-id={content.APP_STORE_APP_ID}">
<meta name="theme-color" content="{THEME_COLOR}">
<link rel="icon" type="image/png" sizes="32x32" href="{root}icon/favicon-32.png">
<link rel="apple-touch-icon" sizes="180x180" href="{root}icon/favicon-180.png">
<link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
{font_links}
<link rel="stylesheet" href="{root}style.css?v={ASSET_VERSION}">
<script src="{root}site.js?v={ASSET_VERSION}" defer></script>{schema_scripts}
</head>
<body class="lang-{language_code}">
<a class="skip-link" href="#main">{escape(copy['ui']['skip'])}</a>
"""


def render_alternate_links(alternate_paths):
    """hreflang 상호 연결 (x-default 는 한국어 기본)"""
    if len(alternate_paths) < 2:
        return ""
    lines = [f'<link rel="alternate" hreflang="{content.LANGUAGES[code]["html_lang"]}" href="{absolute_url(path)}">'
             for code, path in alternate_paths.items()]
    default_path = alternate_paths.get(content.DEFAULT_LANGUAGE_CODE)
    if default_path is not None:
        lines.append(f'<link rel="alternate" hreflang="x-default" href="{absolute_url(default_path)}">')
    return "\n" + "\n".join(lines)


def render_nav(language_code, root, language_menu_paths, cta_href="#download"):
    """상단 메뉴: 로고 > 섹션 링크 > 언어 전환 > 받기 버튼 (모든 페이지 같은 자리·모양)
    language_menu_paths: 언어별 같은 페이지 경로 (없는 언어는 그 언어 첫 화면)
    """
    ui = content.load_home_copy(language_code)["ui"]
    home_link = (root + content.home_path(language_code)) or "./"
    section_links = "".join(
        f'<a href="{home_link}#{anchor}">{escape(ui[key])}</a>'
        for anchor, key in [("arrive", "nav_arrive"), ("shuttle", "nav_shuttle"), ("features", "nav_features"), ("faq", "nav_faq")]
    )
    guide_link = f'<a href="{root}{content.guide_index_path(language_code)}">{escape(ui["nav_guides"])}</a>'
    return f"""<header class="nav" id="nav">
  <div class="wrap nav-in">
    <a class="brand" href="{home_link}"><img src="{root}icon/pin.png" width="14" height="20" alt="">{escape(ui['brand'])}</a>
    <nav class="nav-links" aria-label="{escape(ui['brand'])}">{section_links}{guide_link}</nav>
    <div class="nav-actions">
      {render_language_menu(language_code, root, language_menu_paths)}
      <a class="nav-cta" href="{cta_href}">{escape(ui['cta'])}</a>
    </div>
  </div>
</header>
"""


def render_language_menu(language_code, root, language_menu_paths):
    ui = content.load_home_copy(language_code)["ui"]
    option_links = []
    for code, language in content.LANGUAGES.items():
        target_path = root + language_menu_paths.get(code, content.home_path(code)) or "./"
        current_attribute = ' aria-current="true"' if code == language_code else ""
        option_links.append(f'<a href="{target_path}" hreflang="{language["html_lang"]}" lang="{language["html_lang"]}"'
                            f'{current_attribute}>{escape(language["label"])}</a>')
    options = "".join(option_links)
    current_label = escape(content.LANGUAGES[language_code]["label"])
    return f"""<details class="lang-menu">
        <summary aria-label="{escape(ui['language'])}">{render_icon('globe', 16)}<span>{current_label}</span>{render_icon('chevron_down', 14)}</summary>
        <div class="lang-options">{options}</div>
      </details>"""


def render_store_buttons(language_code, variant="dark", element_id=""):
    """App Store · Google Play 버튼 (variant: dark 밝은 바탕용, light 어두운 바탕용)"""
    ui = content.load_home_copy(language_code)["ui"]
    id_attribute = f' id="{element_id}"' if element_id else ""
    return f"""<div class="store-buttons store-{variant}"{id_attribute}>
  <a class="store-button store-primary" href="{content.app_store_url(language_code)}" rel="noopener">{APPLE_LOGO}<span><small>{escape(ui['store_small'])}</small>{escape(ui['app_store'])}</span></a>
  <a class="store-button store-secondary" href="{content.play_store_url(language_code)}" rel="noopener">{PLAY_LOGO}<span><small>{escape(ui['store_small'])}</small>{escape(ui['google_play'])}</span></a>
</div>"""


def render_footer(language_code, root):
    ui = content.load_home_copy(language_code)["ui"]
    year = content.GUIDE_PUBLISHED_DATE[:4]
    guide_links = "".join(
        f'<a href="{root}{content.guide_path(language_code, slug)}">{escape(title)}</a>'
        for slug, title in guide_titles(language_code)
    )
    return f"""<footer class="footer">
  <div class="wrap footer-in">
    <div class="footer-brand">
      <a class="brand" href="{root + content.home_path(language_code) or './'}"><img src="{root}icon/pin.png" width="14" height="20" alt="">{escape(ui['brand'])}</a>
      <p>{escape(ui['footer_note'])}</p>
    </div>
    <nav class="footer-links" aria-label="{escape(ui['nav_guides'])}"><strong>{escape(ui['nav_guides'])}</strong>{guide_links}</nav>
    <nav class="footer-links" aria-label="{escape(ui['home'])}"><strong>{escape(ui['brand'])}</strong>
      <a href="{root}{content.legal_path(language_code, 'privacy')}">{escape(ui['privacy'])}</a>
      <a href="{root}{content.legal_path(language_code, 'terms')}">{escape(ui['terms'])}</a>
      <a href="mailto:{content.CONTACT_EMAIL}">{escape(ui['contact'])}</a>
    </nav>
  </div>
  <p class="wrap footer-business">{render_business_info(ui)}</p>
  <div class="wrap footer-bottom"><span>© {year} {escape(content.BUSINESS_NAME)}</span>{render_language_menu(language_code, root, {})}</div>
</footer>
</body>
</html>
"""


def render_business_info(ui):
    """사업자 정보 한 줄: 상호 · 대표자 · 사업자등록번호 · 통신판매업 신고번호 · 문의 (라벨만 언어별)"""
    items = [
        (ui["footer_business_name"], escape(content.BUSINESS_NAME)),
        (ui["footer_business_representative"], escape(content.BUSINESS_REPRESENTATIVE)),
        (ui["footer_business_registration"], escape(content.BUSINESS_REGISTRATION_NUMBER)),
        (ui["footer_mail_order_registration"], escape(content.MAIL_ORDER_REGISTRATION_NUMBER)),
        (ui["footer_business_contact"],
         f'<a href="mailto:{content.BUSINESS_CONTACT_EMAIL}">{escape(content.BUSINESS_CONTACT_EMAIL)}</a>'),
    ]
    return "".join(f"<span>{escape(label)} {value}</span>" for label, value in items)


def guide_titles(language_code):
    articles = content.load_guide_copy(language_code)["articles"]
    return [(slug, articles[slug]["tag"]) for slug in content.GUIDE_SLUGS]
