# -*- coding: utf-8 -*-
"""법적 페이지: _src/hand_managed/ 원본(손 관리)의 본문을 새 틀에 그대로 담음 (본문 한 글자도 바꾸지 않음)
원본 2개 언어(ko·en) > ja·zh 는 상단 메뉴·하단에서 영어본으로 연결
"""

import html
import os
import re

import site_content as content
from site_head import render_footer, render_head, render_nav

HAND_MANAGED_DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hand_managed")
# 원본에서 읽는 세 부분: 제목·설명·<main class="doc"> 안쪽
TITLE_PATTERN = re.compile(r"<title>(.*?)</title>", re.S)
DESCRIPTION_PATTERN = re.compile(r'<meta name="description" content="(.*?)">', re.S)
MAIN_CONTENT_PATTERN = re.compile(r'<main class="doc">(.*?)</main>', re.S)


def legal_file_name(language_code, page_name):
    return content.legal_path(language_code, page_name)


def read_hand_managed_page(file_name):
    """원본 > (제목, 설명, 본문 HTML). 형식이 바뀌어 못 읽으면 빌드 중단 (빈 방침 배포 방지)"""
    with open(os.path.join(HAND_MANAGED_DIRECTORY, file_name), encoding="utf-8") as file:
        page_text = file.read()
    matches = [pattern.search(page_text) for pattern in (TITLE_PATTERN, DESCRIPTION_PATTERN, MAIN_CONTENT_PATTERN)]
    if not all(matches):
        raise SystemExit(f"[site build] legal source unreadable : {file_name}")
    title_match, description_match, main_match = matches
    # 원본 문자열은 이미 HTML 이스케이프 상태 > 다시 이스케이프하지 않도록 풀어서 넘김
    return unescape_attribute(title_match.group(1)), unescape_attribute(description_match.group(1)), main_match.group(1)


def unescape_attribute(text):
    return html.unescape(text).strip()


def render_legal_page(language_code, page_name):
    """language_code 는 원본 언어(ko·en)"""
    file_name = legal_file_name(language_code, page_name)
    title, description, main_html = read_hand_managed_page(file_name)
    root = content.relative_root(file_name)
    alternates = {code: legal_file_name(code, page_name) for code in content.LEGAL_SOURCE_LANGUAGE_CODES}
    page = {"language": language_code, "path": file_name, "alternates": alternates, "title": title, "description": description}
    body = f"""<main id="main" class="legal">
<div class="legal-card">{main_html}</div>
</main>
"""
    return (render_head(page, root)
            + render_nav(language_code, root, alternates, cta_href=f"{root}{content.home_path(language_code) or './'}#download")
            + body + render_footer(language_code, root))

