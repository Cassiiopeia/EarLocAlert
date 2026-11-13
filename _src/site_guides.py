# -*- coding: utf-8 -*-
"""정보 글 (언어별 4편 + 목록): 고민 공감 > 앱 없이 하는 방법 > 다운로드 띠 > 앱으로 해결 > 질문 > 다운로드 > 관련 글
경로: {언어 접두어}guide/ (목록), {언어 접두어}guide/{slug}/ (글) > 같은 slug 끼리 hreflang 연결
"""

from html import escape

import site_content as content
from site_head import format_inline, render_footer, render_head, render_nav, render_store_buttons
from site_home_sections import render_faq_list, render_guide_cards, render_phone
from site_icons import render_icon
from site_schema import build_article_schema, build_breadcrumb_schema, build_faq_schema


def render_breadcrumb(name_path_pairs, root):
    """빵부스러기 화면 표시 (마지막 항목은 현재 페이지 > 링크 없음)"""
    items = []
    for index, (name, path) in enumerate(name_path_pairs):
        is_last = index == len(name_path_pairs) - 1
        link_href = (root + path) or "./"
        items.append(f'<li aria-current="page">{escape(name)}</li>' if is_last
                     else f'<li><a href="{link_href}">{escape(name)}</a></li>')
    return f'<nav class="breadcrumb" aria-label="breadcrumb"><ol>{"".join(items)}</ol></nav>'


def render_download_band(language_code, root, element_id=""):
    """글 중간·끝 다운로드 띠: 앱 아이콘 + 한 줄 설득 + 스토어 버튼"""
    ui = content.load_home_copy(language_code)["ui"]
    return f"""<aside class="download-band">
  <img class="band-icon" src="{root}icon/icon-512.png" width="64" height="64" alt="" loading="lazy">
  <div class="band-copy"><strong>{escape(ui['band_title'])}</strong><p>{escape(ui['band_body'])}</p></div>
  {render_store_buttons(language_code, "light", element_id)}
</aside>"""


def render_text_block(block):
    """제목 + 문단 + 목록 (문구의 **굵게** 허용)"""
    paragraphs = "".join(f"<p>{format_inline(paragraph)}</p>" for paragraph in block.get("paragraphs", []))
    items = "".join(f"<li>{format_inline(item)}</li>" for item in block.get("items", []))
    item_list = f"<ul>{items}</ul>" if items else ""
    return f"<h2>{escape(block['heading'])}</h2>{paragraphs}{item_list}"


def render_guide_page(language_code, slug):
    copy, guide_copy = content.load_home_copy(language_code), content.load_guide_copy(language_code)
    ui, article = copy["ui"], guide_copy["articles"][slug]
    page_path = content.guide_path(language_code, slug)
    root = content.relative_root(page_path)
    page_url = content.SITE_URL + page_path
    alternates = {code: content.guide_path(code, slug) for code in content.LANGUAGE_CODES}
    breadcrumb_pairs = [(copy["meta"]["app_name"], content.home_path(language_code)),
                        (ui["nav_guides"], content.guide_index_path(language_code)), (article["title"], page_path)]
    image_url = content.SITE_URL + f"shots/{language_code}/alert.jpg"
    page = {
        "language": language_code, "path": page_path, "alternates": alternates, "og_type": "article",
        "title": f"{article['title']} · {copy['meta']['app_name']}", "description": article["description"], "keywords": article["keywords"],
        "schemas": [
            build_article_schema(language_code, article, page_url, image_url),
            build_faq_schema(article["faq"]),
            build_breadcrumb_schema([(name, content.SITE_URL + path) for name, path in breadcrumb_pairs]),
        ],
    }
    intro = "".join(f"<p>{format_inline(paragraph)}</p>" for paragraph in article["intro"])
    first_section, *other_sections = article["sections"]
    other_sections_html = "".join(render_text_block(section) for section in other_sections)
    app_phone = render_phone(f"{root}shots/{language_code}/alert.jpg", copy["hero"]["phone_alt"], "app-box-phone")
    related_slugs = [other_slug for other_slug in content.GUIDE_SLUGS if other_slug != slug]
    body = f"""<main id="main">
<header class="article-hero">
  <div class="wrap narrow">
    {render_breadcrumb(breadcrumb_pairs, root)}
    <span class="guide-tag">{escape(article['tag'])}</span>
    <h1>{escape(article['title'])}</h1>
    <p class="article-lead">{escape(article['description'])}</p>
    <p class="article-meta">{render_icon('check', 14)} {escape(ui['updated'])} <time datetime="{content.GUIDE_PUBLISHED_DATE}">{content.GUIDE_PUBLISHED_DATE}</time></p>
  </div>
</header>
<article class="article wrap narrow">
  <div class="article-intro">{intro}</div>
  {render_text_block(first_section)}
  {other_sections_html}
  {render_download_band(language_code, root)}
  <section class="app-box">
    <div class="app-box-copy">{render_text_block(article['app'])}</div>
    {app_phone}
  </section>
  <section class="article-faq"><h2>{escape(copy['faq']['kicker'])}</h2><div class="faq-list">{render_faq_list(article['faq'])}</div></section>
  {render_download_band(language_code, root, "download")}
</article>
<section class="related">
  <div class="wrap"><h2>{escape(ui['related'])}</h2><div class="guide-grid guide-grid-three">{render_guide_cards(language_code, root, related_slugs, ui['read_more'])}</div></div>
</section>
</main>
"""
    return render_head(page, root) + render_nav(language_code, root, alternates) + body + render_footer(language_code, root)


def render_guide_index_page(language_code):
    copy, guide_copy = content.load_home_copy(language_code), content.load_guide_copy(language_code)
    ui, index_copy = copy["ui"], guide_copy["index"]
    page_path = content.guide_index_path(language_code)
    root = content.relative_root(page_path)
    alternates = {code: content.guide_index_path(code) for code in content.LANGUAGE_CODES}
    breadcrumb_pairs = [(copy["meta"]["app_name"], content.home_path(language_code)), (ui["nav_guides"], page_path)]
    page = {
        "language": language_code, "path": page_path, "alternates": alternates,
        "title": index_copy["title"], "description": index_copy["description"],
        "schemas": [build_breadcrumb_schema([(name, content.SITE_URL + path) for name, path in breadcrumb_pairs])],
    }
    body = f"""<main id="main">
<header class="article-hero">
  <div class="wrap narrow">
    {render_breadcrumb(breadcrumb_pairs, root)}
    <h1>{escape(index_copy['heading'])}</h1>
    <p class="article-lead">{escape(index_copy['lead'])}</p>
  </div>
</header>
<section class="related related-index">
  <div class="wrap"><div class="guide-grid">{render_guide_cards(language_code, root, content.GUIDE_SLUGS, ui['read_more'])}</div>
  <div class="narrow-band">{render_download_band(language_code, root, "download")}</div></div>
</section>
</main>
"""
    return render_head(page, root) + render_nav(language_code, root, alternates) + body + render_footer(language_code, root)
