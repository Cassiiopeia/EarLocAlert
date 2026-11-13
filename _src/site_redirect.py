# -*- coding: utf-8 -*-
"""옛 주소(github.io) 이동 페이지: 경로마다 canonical·즉시 이동·새 주소 안내 링크
noindex 없음 > canonical 로 새 주소에 색인 이전 신호
"""

from html import escape

# 이동 페이지 문구 (네 언어 사용자 공통 > 한국어·영어 병기)
REDIRECT_PAGE_TITLE = "이어폰위치알림 · EarLocAlert"
REDIRECT_PAGE_MESSAGES = [
    "소개 사이트가 새 주소로 옮겼어요. 잠시 후 자동으로 이동합니다.",
    "This site has moved to a new address. Redirecting…",
]


def to_redirect_file_path(page_path):
    """사이트 경로 > 파일 경로 ('' > index.html, 'guide/' > guide/index.html, 'en.html' 그대로)"""
    if page_path == "" or page_path.endswith("/"):
        return page_path + "index.html"
    return page_path


def render_redirect_page(target_url):
    """target_url 로 보내는 정적 이동 페이지 (meta refresh + 해시 유지용 location.replace)"""
    safe_url = escape(target_url, quote=True)
    messages = "".join(f"<p>{escape(message)}</p>" for message in REDIRECT_PAGE_MESSAGES)
    return f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{REDIRECT_PAGE_TITLE}</title>
<link rel="canonical" href="{safe_url}">
<meta http-equiv="refresh" content="0; url={safe_url}">
<script>location.replace({target_url!r} + location.hash);</script>
</head>
<body>
{messages}
<p><a href="{safe_url}">{safe_url}</a></p>
</body>
</html>
"""


def render_redirect_robots(target_site_url):
    # 수집은 허용 유지 (이동 페이지의 canonical 을 읽어야 이전 신호가 전달됨)
    return f"""User-agent: *
Allow: /
Sitemap: {target_site_url}sitemap.xml
"""
