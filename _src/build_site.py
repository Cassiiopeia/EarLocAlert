# -*- coding: utf-8 -*-
"""소개 사이트 생성 (#365): 언어별 랜딩 4 · 정보 글 목록 4 · 정보 글 16 · 법적 4 · 404 · sitemap · robots · app-ads.txt
실행: python3 -I _src/build_site.py  (gh-pages 루트에서, 결과물 덮어쓰기)
시놀로지용: python3 -I _src/build_site.py --out <폴더> --custom-domain  (보유 도메인 기준 전체 사이트를 별도 폴더에, CNAME 없음)
옛 주소 이동: python3 -I _src/build_site.py --redirect-to https://earlocalert.suhsaechan.kr/  (gh-pages 루트를 새 주소 이동 페이지로, sitemap 제거)
GitHub Pages 커스텀 도메인: site_content.IS_CUSTOM_DOMAIN_ACTIVE = True > 재생성 (CNAME 까지)
"""

import argparse
import datetime
import os
import shutil
import sys

# 생성기 모듈 캐시(__pycache__)를 사이트 브랜치에 남기지 않음
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import site_content as content  # noqa: E402
from site_guides import render_guide_index_page, render_guide_page  # noqa: E402
from site_head import render_footer, render_head, render_nav  # noqa: E402
from site_home import render_home_page  # noqa: E402
from site_legal import render_legal_page  # noqa: E402
from site_redirect import render_redirect_page, render_redirect_robots, to_redirect_file_path  # noqa: E402

SITE_ROOT_DIRECTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 결과물 폴더 (기본 gh-pages 루트, --out 이면 그 폴더)
output_directory = SITE_ROOT_DIRECTORY
# --out 일 때 gh-pages 루트에서 그대로 복사하는 정적 자산 (생성하지 않는 파일)
STATIC_ASSET_PATHS = ["style.css", "site.js", "icon", "shots", "video", "badges", ".nojekyll"]
# --redirect-to 일 때 지우는 옛 주소 파일 (sitemap: 다른 호스트 주소를 담을 수 없음, CNAME: 커스텀 도메인 미사용)
REDIRECT_REMOVED_PATHS = ["sitemap.xml", "CNAME"]
# sitemap 우선순위: 랜딩 1.0, 글 0.8, 글 목록 0.6, 법적 0.3
SITEMAP_PRIORITY_HOME, SITEMAP_PRIORITY_GUIDE, SITEMAP_PRIORITY_GUIDE_INDEX, SITEMAP_PRIORITY_LEGAL = "1.0", "0.8", "0.6", "0.3"


def write_file(relative_path, text):
    full_path = os.path.join(output_directory, relative_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as file:
        file.write(text)


def collect_page_groups():
    """sitemap·이동 페이지 공통 목록: [(우선순위, {언어: 경로})] (같은 내용의 언어별 경로 묶음)"""
    page_groups = [(SITEMAP_PRIORITY_HOME, {code: content.home_path(code) for code in content.LANGUAGE_CODES}),
                   (SITEMAP_PRIORITY_GUIDE_INDEX, {code: content.guide_index_path(code) for code in content.LANGUAGE_CODES})]
    page_groups += [(SITEMAP_PRIORITY_GUIDE, {code: content.guide_path(code, slug) for code in content.LANGUAGE_CODES})
                    for slug in content.GUIDE_SLUGS]
    page_groups += [(SITEMAP_PRIORITY_LEGAL, {code: content.legal_path(code, name) for code in content.LEGAL_SOURCE_LANGUAGE_CODES})
                    for name in content.LEGAL_PAGE_NAMES]
    return page_groups


def write_pages():
    """언어별 랜딩·글 목록·글 + 법적 페이지 > 생성 건수"""
    written_count = 0
    for language_code in content.LANGUAGE_CODES:
        write_file(to_redirect_file_path(content.home_path(language_code)), render_home_page(language_code))
        write_file(to_redirect_file_path(content.guide_index_path(language_code)), render_guide_index_page(language_code))
        for slug in content.GUIDE_SLUGS:
            write_file(to_redirect_file_path(content.guide_path(language_code, slug)), render_guide_page(language_code, slug))
        written_count += 2 + len(content.GUIDE_SLUGS)
    for language_code in content.LEGAL_SOURCE_LANGUAGE_CODES:
        for page_name in content.LEGAL_PAGE_NAMES:
            write_file(content.legal_path(language_code, page_name), render_legal_page(language_code, page_name))
            written_count += 1
    return written_count


def render_not_found_page():
    """어느 깊이에서나 열리므로 절대 루트 경로 (한국어 기본, 영어 링크 병기)"""
    ui = content.load_home_copy(content.DEFAULT_LANGUAGE_CODE)["ui"]
    english_ui = content.load_home_copy("en")["ui"]
    root = content.SITE_ROOT_PATH
    page = {"language": content.DEFAULT_LANGUAGE_CODE, "path": "404.html", "is_indexable": False,
            "title": f"{ui['not_found_title']} · {ui['brand']}", "description": ui["not_found_body"]}
    return render_head(page, root) + render_nav(content.DEFAULT_LANGUAGE_CODE, root, {}, cta_href=f"{root}#download") + f"""<main id="main">
<header class="article-hero not-found">
  <div class="wrap narrow">
    <h1>{ui['not_found_title']}</h1>
    <p class="article-lead">{ui['not_found_body']}<br>{english_ui['not_found_body']}</p>
    <p class="not-found-links"><a class="pill-link" href="{root}">{ui['not_found_cta']}</a><a class="pill-link" href="{root}en.html">{english_ui['not_found_cta']}</a></p>
  </div>
</header>
</main>
""" + render_footer(content.DEFAULT_LANGUAGE_CODE, root)


def render_sitemap(today_text):
    """언어별 주소마다 hreflang 대체 주소를 함께 (검색엔진이 언어판을 묶어 보게)"""
    entries = []
    for priority, path_by_language in collect_page_groups():
        alternates = "".join(
            f'\n    <xhtml:link rel="alternate" hreflang="{content.LANGUAGES[code]["html_lang"]}" href="{content.SITE_URL}{path}"/>'
            for code, path in path_by_language.items()
        ) if len(path_by_language) > 1 else ""
        for path in path_by_language.values():
            entries.append(f"""
  <url>
    <loc>{content.SITE_URL}{path}</loc>{alternates}
    <lastmod>{today_text}</lastmod>
    <priority>{priority}</priority>
  </url>""")
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">{"".join(entries)}
</urlset>
"""


def render_robots():
    # 검색엔진은 도메인 루트 robots.txt 만 읽음: github.io 하위면 참고용(sitemap 은 콘솔 제출), 보유 도메인이면 그대로 유효
    return f"""User-agent: *
Allow: /
Sitemap: {content.SITE_URL}sitemap.xml
"""


def write_custom_domain_file():
    """GitHub Pages 커스텀 도메인 CNAME: 이전 스위치가 켜졌을 때만 (꺼져 있는데 남았으면 경고)"""
    if content.IS_CUSTOM_DOMAIN_ACTIVE:
        write_file("CNAME", content.CUSTOM_DOMAIN_HOST + "\n")
        return
    if os.path.exists(os.path.join(output_directory, "CNAME")):
        print("[site build] warning : CNAME exists while IS_CUSTOM_DOMAIN_ACTIVE is False")


def copy_static_files():
    """--out 전용: 정적 자산 복사 (gh-pages 루트 > 결과물 폴더)"""
    for relative_path in STATIC_ASSET_PATHS:
        source_path = os.path.join(SITE_ROOT_DIRECTORY, relative_path)
        target_path = os.path.join(output_directory, relative_path)
        if os.path.isdir(source_path):
            shutil.copytree(source_path, target_path, dirs_exist_ok=True)
        elif os.path.exists(source_path):
            shutil.copy2(source_path, target_path)


def write_redirect_site(target_site_url):
    """옛 주소 이동: 모든 페이지를 같은 경로의 새 주소로, 404 는 새 주소 첫 화면으로 (정적 자산은 그대로 둠)"""
    page_paths = [path for _, path_by_language in collect_page_groups() for path in path_by_language.values()]
    for page_path in page_paths:
        write_file(to_redirect_file_path(page_path), render_redirect_page(target_site_url + page_path))
    write_file("404.html", render_redirect_page(target_site_url))
    write_file("robots.txt", render_redirect_robots(target_site_url))
    for relative_path in REDIRECT_REMOVED_PATHS:
        removed_path = os.path.join(SITE_ROOT_DIRECTORY, relative_path)
        if os.path.exists(removed_path):
            os.remove(removed_path)
    print(f"[site build] redirect pages {len(page_paths) + 1} : -> {target_site_url}")


def parse_arguments():
    parser = argparse.ArgumentParser(description="이어폰위치알림 소개 사이트 생성")
    parser.add_argument("--out", help="결과물 폴더 (없으면 gh-pages 루트에 덮어쓰기)")
    parser.add_argument("--custom-domain", action="store_true", help=f"{content.CUSTOM_DOMAIN_SITE_URL} 기준으로 생성")
    parser.add_argument("--redirect-to", help="gh-pages 루트를 이 주소로 보내는 이동 페이지로 생성 (예: https://earlocalert.suhsaechan.kr/)")
    return parser.parse_args()


def main():
    global output_directory
    arguments = parse_arguments()
    if arguments.redirect_to:
        write_redirect_site(arguments.redirect_to.rstrip("/") + "/")
        return
    if arguments.custom_domain:
        content.use_custom_domain()
    if arguments.out:
        output_directory = os.path.abspath(arguments.out)
        os.makedirs(output_directory, exist_ok=True)
        copy_static_files()
    today_text = datetime.date.today().isoformat()
    page_count = write_pages()
    write_file("404.html", render_not_found_page())
    write_file("sitemap.xml", render_sitemap(today_text))
    write_file("robots.txt", render_robots())
    write_file("app-ads.txt", content.APP_ADS_TEXT)
    if not arguments.out:
        write_custom_domain_file()
    print(f"[site build] pages {page_count} + 404 : {content.SITE_URL} -> {output_directory}")


if __name__ == "__main__":
    main()
