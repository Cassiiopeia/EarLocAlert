"""소개 페이지 다국어 생성: 한국어 원본(index.html) > en·ja·zh 페이지 + sitemap (#281)

    python3 -I tool/store_art/landing/make_lang_pages.py <gh-pages 폴더>

- 원본은 한국어 페이지 하나. 다른 언어는 이 스크립트로만 만든다 (손으로 고치지 않음)
- 본문 한국어 문구 > lang_texts.json 사전, head(제목·설명·구조화 데이터)는 언어별로 새로 씀
- 화면 섹션 > 언어별 홍보 이미지(shots/<lang>/01~06.jpg), 문구는 scenes.json
- 네 페이지 모두 hreflang 으로 서로를 가리킴
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SITE_DIR = Path(sys.argv[1])
SITE = "https://cassiiopeia.github.io/EarLocAlert/"
# 언어별 페이지 파일 (ko 는 사이트 루트)
PAGE_BY_LANG = {"ko": "", "en": "en.html", "ja": "ja.html", "zh": "zh.html"}
APP_STORE_COUNTRY_BY_LANG = {"ko": "kr", "en": "us", "ja": "jp", "zh": "cn"}
PLAY_LANGUAGE_PARAM_BY_LANG = {"ko": "", "en": "&amp;hl=en", "ja": "&amp;hl=ja", "zh": "&amp;hl=zh-CN"}
OG_LOCALE_BY_LANG = {"ko": "ko_KR", "en": "en_US", "ja": "ja_JP", "zh": "zh_CN"}
LANGUAGE_NAME_BY_LANG = {"ko": "한국어", "en": "English", "ja": "日本語", "zh": "中文"}
PLAY_URL = "https://play.google.com/store/apps/details?id=kr.suhsaechan.ear_loc_alert"
APP_STORE_ID = "6755805664"
# 한국어 페이지에만 있어야 하는 고유명사 — 다른 언어 페이지에 남아도 정상
ALLOWED_KOREAN_WORDS = {"한국어", "서새찬"}


# 홍보 영상: 소리 없이 자동 반복 (iOS 인라인 재생을 위해 playsinline), 못 불러오면 포스터
HERO_VIDEO_HTML = (
    '<video class="phone" width="486" height="1054" autoplay muted loop playsinline preload="metadata" '
    'poster="video/promo_poster.jpg" aria-label="장소를 등록하고 도착하면 알림이 울리는 과정을 보여주는 영상">'
    '<source src="video/promo.mp4" type="video/mp4"></video>'
)


HERO_IMAGE_HTML = (
    '<img class="phone" src="shots/ko/alert.jpg" width="486" height="1054" '
    'alt="도착 알림 화면. 장소 이름과 도착 시각, 주변 지도, 화면 아래 알림 끄기 버튼이 보인다.">'
)


def app_store_url(lang):
    return f"https://apps.apple.com/{APP_STORE_COUNTRY_BY_LANG[lang]}/app/id{APP_STORE_ID}"


def hreflang_links():
    links = "".join(f'<link rel="alternate" hreflang="{lang}" href="{SITE}{page}">\n' for lang, page in PAGE_BY_LANG.items())
    return links + f'<link rel="alternate" hreflang="x-default" href="{SITE}">\n'


def language_switcher_links(current_lang):
    return " ".join(
        f'<a href="{PAGE_BY_LANG[lang] or "./"}" hreflang="{lang}" lang="{lang}">{LANGUAGE_NAME_BY_LANG[lang]}</a>'
        for lang in PAGE_BY_LANG if lang != current_lang
    )


def strip_tags(text):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text)).strip()


def screens_section_html(lang, scenes):
    """화면 섹션: 홍보 이미지 6장, alt 는 그 장면의 문구"""
    figures = []
    for scene in scenes:
        alt = f'{strip_tags(scene["headline"][lang])} — {scene["sub"][lang]}'
        figures.append(
            f'''      <figure class="shot" style="margin:0">
        <img class="promo" loading="lazy" src="shots/{lang}/{scene["id"]}.jpg" width="540" height="960" alt="{alt}">
      </figure>''')
    return '<div class="shots">\n' + "\n".join(figures) + "\n    </div>"


def head_html(lang, texts):
    page_url = SITE + PAGE_BY_LANG[lang]
    structured_data = [
        {"@context": "https://schema.org", "@type": "MobileApplication", "name": texts["app_name"],
         "alternateName": ["EarLocAlert", "이어폰위치알림"], "operatingSystem": "iOS, Android",
         "applicationCategory": "TravelApplication", "description": texts["ld_desc"],
         "offers": {"@type": "Offer", "price": "0", "priceCurrency": texts["currency"]},
         "url": page_url, "image": f"{SITE}icon/og-{lang}.png", "inLanguage": lang,
         "downloadUrl": [app_store_url(lang), PLAY_URL]},
        {"@context": "https://schema.org", "@type": "FAQPage",
         "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in texts["faq"]]},
    ]
    alternate_locales = "".join(
        f'<meta property="og:locale:alternate" content="{OG_LOCALE_BY_LANG[other]}">\n' for other in PAGE_BY_LANG if other != lang)
    return f'''<title>{texts["title"]}</title>
<meta name="description" content="{texts["desc"]}">
<meta name="keywords" content="{texts["keywords"]}">
<link rel="canonical" href="{page_url}">
{hreflang_links()}<meta property="og:site_name" content="{texts["app_name"]}">
<meta property="og:locale" content="{OG_LOCALE_BY_LANG[lang]}">
{alternate_locales}<meta property="og:title" content="{texts["og_title"]}">
<meta property="og:description" content="{texts["og_desc"]}">
<meta property="og:type" content="website">
<meta property="og:image" content="{SITE}icon/og-{lang}.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="{page_url}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{texts["og_title"]}">
<meta name="twitter:description" content="{texts["og_desc"]}">
<meta name="twitter:image" content="{SITE}icon/og-{lang}.png">
<meta name="apple-itunes-app" content="app-id={APP_STORE_ID}">
<meta name="theme-color" content="#0b0d0c">
<script type="application/ld+json">
{json.dumps(structured_data, ensure_ascii=False, indent=1)}
</script>
'''


def long_korean_texts(korean_page):
    """사전 키(LEAD 등) > 한국어 원문. 긴 문장은 페이지에서 직접 뽑는다"""
    def grab(pattern):
        return re.search(pattern, korean_page, re.S).group(1)

    texts = {
        "LEAD": grab(r'<p class="lead">\s*(.*?)\s*</p>'),
        "PITCH": grab(r"이어폰이 연결됐는지 확인한 뒤에만</strong>\s*(.*?)\s*</p>"),
        "PRIV": grab(r'위치 정보는 기기 밖으로 나가지 않습니다</h2>\s*<p class="sec-lead"[^>]*>\s*(.*?)\s*</p>'),
        "NOTE": grab(r'<p class="note">(.*?)</p>'),
        "HERO_ALT": grab(r'<div class="hero-art">.*?alt="(.*?)"'),
    }
    for index, (_, paragraph) in enumerate(re.findall(r"<h3>(.*?)</h3>\s*<p>(.*?)</p>", korean_page, re.S)[:6], start=1):
        texts[f"F{index}"] = paragraph
    for index, item in enumerate(re.findall(r'<span class="tick">✓</span><span>(.*?)</span>', korean_page), start=1):
        texts[f"P{index}"] = item
    return texts


def build_language_page(korean_page, lang, texts, korean_faq_questions):
    page = korean_page
    # 자주 묻는 질문 (질문·답 짝으로 교체)
    for (question, answer), korean_question in zip(texts["faq"], korean_faq_questions):
        korean_answer = re.search(re.escape(korean_question) + r"</summary>\s*<p>(.*?)</p>", page, re.S).group(1)
        page = page.replace(f"<summary>{korean_question}</summary>", f"<summary>{question}</summary>", 1)
        page = page.replace(f"<p>{korean_answer}</p>", f"<p>{answer}</p>", 1)
    page = page[:page.index("<title>")] + head_html(lang, texts) + page[page.index('<link rel="icon"'):]
    page = page.replace('<html lang="ko">', f'<html lang="{lang}">', 1)

    body_start = page.index("<body>")
    body = page[body_start:]
    replacements = dict(texts["T"])
    for key, korean_text in long_korean_texts(korean_page).items():
        if key in replacements:
            replacements[korean_text] = replacements.pop(key)
    # 긴 문구부터 (짧은 키가 긴 문장 일부를 먼저 바꾸지 않게)
    for korean_text in sorted(replacements, key=len, reverse=True):
        translated = replacements[korean_text]
        body = body.replace(f'"{korean_text}"', f'"{translated}"')
        body = re.sub(r"(>\s*)" + re.escape(korean_text) + r"(\s*<)", lambda m: m.group(1) + translated + m.group(2), body)
    body = (body.replace("badges/play-ko.png", f"badges/play-{lang}.png")
            .replace(app_store_url("ko"), app_store_url(lang))
            .replace(f'href="{PLAY_URL}"', f'href="{PLAY_URL}{PLAY_LANGUAGE_PARAM_BY_LANG[lang]}"')
            .replace('href="privacy.html"', 'href="privacy-en.html"')
            .replace('alt="다운로드하기 Google Play"', f'alt="{texts["play_badge_alt"]}"')
            .replace(language_switcher_links("ko"), language_switcher_links(lang), 1)
            .replace('<a href="en.html" hreflang="en">English</a>', '<a href="./" hreflang="ko">한국어</a>'))
    body = re.sub(r"shots/ko/", f"shots/{lang}/", body)
    return page[:body_start] + body


def write_sitemap():
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for lang, page in PAGE_BY_LANG.items():
        lines.append("  <url>")
        lines.append(f"    <loc>{SITE}{page}</loc>")
        lines += [f'    <xhtml:link rel="alternate" hreflang="{other}" href="{SITE}{other_page}"/>' for other, other_page in PAGE_BY_LANG.items()]
        lines.append(f"    <changefreq>weekly</changefreq><priority>{'1.0' if lang == 'ko' else '0.9'}</priority>")
        lines.append("  </url>")
    lines += [f"  <url><loc>{SITE}{doc}</loc><priority>0.3</priority></url>" for doc in
              ["privacy.html", "privacy-en.html", "terms.html", "terms-en.html"]]
    lines.append("</urlset>")
    (SITE_DIR / "sitemap.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    texts_by_lang = json.loads((HERE / "lang_texts.json").read_text(encoding="utf-8"))
    scenes = json.loads((HERE.parent / "scenes.json").read_text(encoding="utf-8"))["scenes"]
    korean_faq_questions = texts_by_lang["_korean_faq_questions"]

    # 한국어 원본: 화면 섹션만 홍보 이미지로 맞춘다
    korean_path = SITE_DIR / "index.html"
    korean_page = korean_path.read_text(encoding="utf-8")
    # 다시 돌려도 같은 결과가 나오게 — 이전에 넣은 영상을 도착 알림 이미지로 되돌리고 시작
    korean_page = korean_page.replace(HERO_VIDEO_HTML, HERO_IMAGE_HTML)
    korean_page = re.sub(r'<div class="shots">.*?\n    </div>', lambda m: screens_section_html("ko", scenes), korean_page, count=1, flags=re.S)
    # 다른 언어 페이지는 영상 넣기 전 본문에서 만든다 (영상은 한국어 화면이라 한국어 페이지에만)
    korean_page_for_translation = korean_page
    korean_page = re.sub(r'<img class="phone" src="shots/ko/alert\.jpg"[^>]*>', HERO_VIDEO_HTML, korean_page, count=1)
    korean_path.write_text(korean_page, encoding="utf-8")

    for lang in ["en", "ja", "zh"]:
        page = build_language_page(korean_page_for_translation, lang, texts_by_lang[lang], korean_faq_questions)
        page = re.sub(r'<div class="shots">.*?\n    </div>', lambda m: screens_section_html(lang, scenes), page, count=1, flags=re.S)
        (SITE_DIR / PAGE_BY_LANG[lang]).write_text(page, encoding="utf-8")
        # 검증 (본문에 남은 한국어, 구조화 데이터 구문)
        visible = re.sub(r"<script.*?</script>", "", page[page.index("<body>"):], flags=re.S)
        leftover = sorted(set(re.findall(r"[가-힣]+", visible)) - ALLOWED_KOREAN_WORDS)
        json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', page, re.S).group(1))
        print(f"{lang}: 남은 한국어 {leftover or '없음'}")
        if leftover:
            sys.exit(f"{lang} 페이지에 번역 안 된 한국어가 있다")
    write_sitemap()
    print("sitemap.xml 갱신")


if __name__ == "__main__":
    main()
