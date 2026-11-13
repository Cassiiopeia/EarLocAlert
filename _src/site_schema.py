# -*- coding: utf-8 -*-
"""검색 구조화 데이터(JSON-LD): 앱 · 자주 묻는 질문 · 빵부스러기 · 글 · 운영자
검색 결과에 앱 정보·질문 답·경로가 바로 보이게 > 정보 글에서 다운로드로 이어지는 입구
"""

import site_content as content

SCHEMA_CONTEXT = "https://schema.org"


def build_mobile_application_schema(language_code, page_url):
    meta = content.load_home_copy(language_code)["meta"]
    return {
        "@context": SCHEMA_CONTEXT,
        "@type": "MobileApplication",
        "name": meta["app_name"],
        "alternateName": ["EarLocAlert", "이어폰위치알림"],
        "operatingSystem": "iOS, Android",
        "applicationCategory": "TravelApplication",
        "description": meta["ld_description"],
        "inLanguage": content.LANGUAGES[language_code]["html_lang"],
        "url": page_url,
        "image": content.SITE_URL + "icon/icon-512.png",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": meta["currency"]},
        "downloadUrl": [content.app_store_url(language_code), content.play_store_url(language_code)],
        "author": build_person_schema(),
    }


def build_person_schema():
    return {"@type": "Person", "name": content.DEVELOPER_NAME, "email": f"mailto:{content.CONTACT_EMAIL}"}


def build_faq_schema(question_answer_pairs):
    """[[질문, 답]] > FAQPage (답의 **굵게** 표시는 지움)"""
    return {
        "@context": SCHEMA_CONTEXT,
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": question,
             "acceptedAnswer": {"@type": "Answer", "text": answer.replace("**", "")}}
            for question, answer in question_answer_pairs
        ],
    }


def build_breadcrumb_schema(name_url_pairs):
    """[(이름, 절대 주소)] > BreadcrumbList (첫 항목이 첫 화면)"""
    return {
        "@context": SCHEMA_CONTEXT,
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": position, "name": name, "item": url}
            for position, (name, url) in enumerate(name_url_pairs, start=1)
        ],
    }


def build_article_schema(language_code, article, page_url, image_url):
    return {
        "@context": SCHEMA_CONTEXT,
        "@type": "Article",
        "headline": article["title"],
        "description": article["description"],
        "inLanguage": content.LANGUAGES[language_code]["html_lang"],
        "mainEntityOfPage": page_url,
        "image": image_url,
        "datePublished": content.GUIDE_PUBLISHED_DATE,
        "dateModified": content.GUIDE_PUBLISHED_DATE,
        "author": build_person_schema(),
        "publisher": build_person_schema(),
    }
