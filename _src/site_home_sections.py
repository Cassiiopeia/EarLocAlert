# -*- coding: utf-8 -*-
"""랜딩 뒷부분 섹션: 사용법(고정 폰) · 기능 벤토 · 이동 가이드 카드 · 자주 묻는 질문 · 마지막 다운로드"""

from html import escape

import site_content as content
from site_head import format_inline, render_store_buttons
from site_icons import render_icon


def render_phone(image_source, image_alt, extra_class="", inner_html="", is_lazy=True):
    """폰 테두리 + 화면 이미지 (486x1054 캡처 비율)"""
    loading = ' loading="lazy"' if is_lazy else ' fetchpriority="high"'
    return (f'<div class="phone {extra_class}"><img src="{image_source}" width="486" height="1054" alt="{escape(image_alt)}"{loading}>'
            f'{inner_html}</div>')


def render_how_section(copy, language_code, root):
    """사용법: 왼쪽 단계 문단이 화면 가운데 오면 오른쪽 고정 폰 화면 교체 (모바일은 단계마다 화면 함께)"""
    how = copy["how"]
    steps = "".join(
        f"""<article class="step{' is-active' if index == 0 else ''}" data-step="{step['shot']}">
          <p class="step-number">{index + 1:02d}</p>
          <h3>{'<br>'.join(escape(line) for line in step['title'])}</h3>
          <p>{escape(step['body'])}</p>
          <img class="step-shot" src="{root}shots/{language_code}/{step['shot']}.jpg" width="486" height="1054" alt="{escape(step['alt'])}" loading="lazy">
        </article>"""
        for index, step in enumerate(how["steps"])
    )
    shots = "".join(
        f'<img class="{"is-active" if index == 0 else ""}" data-shot="{step["shot"]}" src="{root}shots/{language_code}/{step["shot"]}.jpg" '
        f'width="486" height="1054" alt="" loading="lazy">'
        for index, step in enumerate(how["steps"])
    )
    return f"""<section class="how" id="how">
  <div class="wrap">
    <div class="section-head reveal"><p class="kicker">{escape(how['kicker'])}</p><h2>{escape(how['title'])}</h2></div>
    <div class="story">
      <div class="story-steps">{steps}</div>
      <div class="story-phone" aria-hidden="true"><div class="story-glow"></div><div class="phone">{shots}</div></div>
    </div>
  </div>
</section>
"""


def render_features_section(copy, language_code, root):
    features = copy["features"]
    allowed = "".join(f"<span>{escape(name)}</span>" for name in features["allowed_devices"])
    blocked = "".join(f'<span class="is-blocked">{escape(name)}</span>' for name in features["blocked_devices"])
    weekdays = "".join(f"<b>{escape(day)}</b>" for day in features["weekdays"])
    radius_steps = escape("|".join(features["radius_steps"]))
    return f"""<section class="features" id="features">
  <div class="wrap">
    <div class="section-head reveal"><p class="kicker">{escape(features['kicker'])}</p>
      <h2>{escape(features['title_before'])}<br><em>{escape(features['title_accent'])}</em>{escape(features['title_after'])}</h2></div>
    <div class="bento">
      <div class="tile tile-big reveal"><h3>{'<br>'.join(escape(line) for line in features['big_title'])}</h3><p>{escape(features['big_body'])}</p>
        <img src="{root}shots/{language_code}/home.jpg" width="486" height="1054" alt="{escape(features['big_alt'])}" loading="lazy"></div>
      <div class="tile tile-small reveal"><h3>{escape(features['vibration_title'])}</h3><p>{escape(features['vibration_body'])}</p><div class="mini-phone" aria-hidden="true"></div></div>
      <div class="tile tile-small reveal"><h3>{escape(features['radius_title'])}</h3><p>{escape(features['radius_body'])}</p>
        <div class="radius-demo" aria-hidden="true"><div class="radius-circle"></div><img src="{root}icon/pin.png" width="20" height="29" alt=""><span data-radius-steps="{radius_steps}">{escape(features['radius_steps'][0])}</span></div></div>
      <div class="tile tile-wide reveal"><h3>{escape(features['earphone_title'])}</h3><p>{escape(features['earphone_body'])}</p><div class="device-chips">{allowed}{blocked}</div></div>
      <div class="tile tile-wide tile-mint reveal"><h3>{escape(features['schedule_title'])}</h3><p>{escape(features['schedule_body'])}</p><div class="weekday-chips" data-weekdays aria-hidden="true">{weekdays}</div></div>
    </div>
  </div>
</section>
"""


def render_guide_cards(language_code, root, slugs, read_more_label):
    """정보 글 카드 묶음 (랜딩·관련 글 공통)"""
    articles = content.load_guide_copy(language_code)["articles"]
    return "".join(
        f"""<a class="guide-card reveal" href="{root}{content.guide_path(language_code, slug)}">
          <span class="guide-tag">{escape(articles[slug]['tag'])}</span>
          <h3>{escape(articles[slug]['title'])}</h3>
          <p>{escape(articles[slug]['summary'])}</p>
          <span class="guide-more">{escape(read_more_label)} {render_icon('arrow_right', 14)}</span>
        </a>"""
        for slug in slugs
    )


def render_guides_section(copy, language_code, root):
    guides, ui = copy["guides"], copy["ui"]
    cards = render_guide_cards(language_code, root, content.GUIDE_SLUGS, ui["read_more"])
    return f"""<section class="guides" id="guides">
  <div class="wrap">
    <div class="section-head reveal"><p class="kicker">{escape(guides['kicker'])}</p><h2>{escape(guides['title'])}</h2></div>
    <div class="guide-grid">{cards}</div>
  </div>
</section>
"""


def render_faq_list(question_answer_pairs):
    return "".join(
        f'<details class="faq-item"><summary>{escape(question)}{render_icon("plus", 18)}</summary><p>{format_inline(answer)}</p></details>'
        for question, answer in question_answer_pairs
    )


def render_faq_section(copy):
    faq = copy["faq"]
    return f"""<section class="faq" id="faq">
  <div class="wrap faq-grid">
    <div class="section-head reveal"><p class="kicker">{escape(faq['kicker'])}</p><h2>{escape(faq['title'])}</h2></div>
    <div class="faq-list reveal">{render_faq_list(faq['items'])}</div>
  </div>
</section>
"""


def render_final_section(copy, language_code, root):
    final = copy["final"]
    return f"""<section class="final">
  <span class="halo"></span><span class="halo"></span><span class="halo"></span>
  <div class="wrap final-in">
    <img class="final-pin" src="{root}icon/pin.png" width="56" height="80" alt="" loading="lazy">
    <h2>{escape(final['title_before'])}<br><em>{escape(final['title_accent'])}</em></h2>
    {render_store_buttons(language_code, "light", "download")}
  </div>
</section>
"""
