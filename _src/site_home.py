# -*- coding: utf-8 -*-
"""랜딩 페이지 (언어별): 첫 화면 > 도착 연출 > 셔틀 > 사용법 > 기능 > 이동 가이드 > 자주 묻는 질문 > 다운로드
연출 동작은 site.js 가 data-* 속성을 읽어 처리 (문구는 전부 여기서 HTML 로)
"""

from html import escape

import site_content as content
from site_head import render_footer, render_head, render_nav, render_store_buttons
from site_home_sections import (render_faq_section, render_features_section, render_final_section,
                                render_guides_section, render_how_section, render_phone)
from site_icons import render_icon
from site_schema import build_breadcrumb_schema, build_faq_schema, build_mobile_application_schema

# 도착 연출 지도 (viewBox 760x640): 버스 경로·도착 반경 중심·반지름
ARRIVE_ROUTE_PATH = "M-20 330 C 80 320, 120 200, 230 220 S 340 300, 410 230"
ARRIVE_ZONE_CENTER = (410, 230)
ARRIVE_ZONE_RADIUS = 70


def render_hero(copy, language_code, root):
    hero = copy["hero"]
    lead = "<br>".join(escape(line) for line in hero["lead"])
    chips = "".join(
        f'<div class="float-chip chip-{index + 1}"><span class="chip-icon">{render_icon(icon_name)}</span>'
        f'<div>{escape(title)}<small>{escape(subtitle)}</small></div></div>'
        for index, (icon_name, title, subtitle) in enumerate(hero["chips"])
    )
    phone = render_phone(f"{root}shots/{language_code}/alert.jpg", hero["phone_alt"], is_lazy=False)
    return f"""<section class="hero">
  <div class="wrap">
    <p class="eyebrow">{escape(hero['eyebrow'])}</p>
    <h1 class="hero-title" data-word-reveal>{escape(hero['headline_before'])} <em>{escape(hero['headline_accent'])}</em> {escape(hero['headline_after'])}</h1>
    <p class="hero-lead">{lead}</p>
    {render_store_buttons(language_code, "dark")}
  </div>
  <div class="hero-device">
    <div class="hero-tilt" data-tilt>{phone}</div>
    {chips}
  </div>
</section>
"""


def render_arrive_section(copy, language_code, root):
    arrive = copy["arrive"]
    zone_x, zone_y = ARRIVE_ZONE_CENTER
    title = "<br>".join(escape(line) for line in arrive["title"])
    lock_screen = (f'<div class="screen-off" data-screen-off><div><div class="clock">{escape(arrive["clock"])}</div>'
                   f'<div class="clock-label">{render_icon("lock", 13)} {escape(arrive["lock"])}</div></div></div>')
    phone = render_phone(f"{root}shots/{language_code}/alert.jpg", arrive["notification_title"], "night-phone-frame", lock_screen)
    return f"""<section class="arrive" id="arrive">
  <div class="wrap">
    <div class="night" data-arrive data-zone-x="{zone_x}" data-zone-y="{zone_y}" data-zone-radius="{ARRIVE_ZONE_RADIUS}"
         data-status-moving="{escape(arrive['status_moving'])}" data-status-arrived="{escape(arrive['status_arrived'])}">
      <svg class="night-map" viewBox="0 0 760 640" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <defs>
          <pattern id="night-grid" width="48" height="48" patternUnits="userSpaceOnUse"><path d="M48 0H0V48" fill="none" stroke="var(--night-grid)"/></pattern>
          <radialGradient id="zone-gradient"><stop offset="0" stop-color="var(--mint)" stop-opacity=".3"/><stop offset="1" stop-color="var(--mint)" stop-opacity="0"/></radialGradient>
        </defs>
        <rect width="760" height="640" fill="url(#night-grid)"/>
        <path d="M80 0 L 130 640 M 470 0 L 430 640 M 0 150 L 760 110 M 0 520 L 760 560" stroke="var(--night-road)" stroke-width="12"/>
        <path d="{ARRIVE_ROUTE_PATH}" fill="none" stroke="var(--night-road-main)" stroke-width="20" stroke-linecap="round"/>
        <path data-route d="{ARRIVE_ROUTE_PATH}" fill="none" stroke="var(--mint)" stroke-width="3" stroke-dasharray="6 9" opacity=".55"/>
        <circle data-zone-fill cx="{zone_x}" cy="{zone_y}" r="{ARRIVE_ZONE_RADIUS}" fill="url(#zone-gradient)"/>
        <circle data-zone-edge cx="{zone_x}" cy="{zone_y}" r="{ARRIVE_ZONE_RADIUS}" fill="none" stroke="var(--mint)" stroke-width="1.5" opacity=".75"/>
        <text x="{zone_x}" y="{zone_y + ARRIVE_ZONE_RADIUS + 22}" class="night-place" text-anchor="middle">{escape(arrive['place'])}</text>
        <g data-bus transform="translate(-20 330)"><circle r="16" fill="var(--mint)" opacity=".22"/><circle r="7" fill="var(--mint)"/></g>
      </svg>
      <div class="night-copy">
        <p class="kicker">{escape(arrive['kicker'])}</p>
        <h2>{title}</h2>
        <p class="night-body">{escape(arrive['body'])}</p>
        <p class="night-status" data-status role="status">{render_icon('bus', 16)}<span>{escape(arrive['status_moving'])}</span></p>
      </div>
      <div class="night-phone">
        <div class="vibe vibe-left" data-vibe><i></i><i></i><i></i></div>
        <div class="vibe vibe-right" data-vibe><i></i><i></i><i></i></div>
        <div class="notification" data-notification><img src="{root}icon/icon-512.png" width="26" height="26" alt="" loading="lazy">
          <div><b>{escape(arrive['notification_title'])}</b><span>{escape(arrive['notification_body'])}</span></div></div>
        {phone}
      </div>
    </div>
  </div>
</section>
"""


def render_shuttle_section(copy):
    shuttle = copy["shuttle"]
    title = "<br>".join(escape(line) for line in shuttle["title"])
    last_stop_index = len(shuttle["stops"]) - 1
    stops = "".join(
        f'<li class="stop{" stop-target" if index == last_stop_index else ""}" data-stop>{escape(name)}<small>{escape(note)}</small>'
        f'{"" if index == last_stop_index else "<span class=\"stop-silent\">" + render_icon("speaker_off", 14) + "</span>"}</li>'
        for index, (name, note) in enumerate(shuttle["stops"])
    )
    uses = "".join(
        f'<div class="use-card reveal"><span class="use-icon">{render_icon(icon_name, 22)}</span><b>{escape(title_text)}</b><span>{escape(body)}</span></div>'
        for icon_name, title_text, body in shuttle["uses"]
    )
    return f"""<section class="shuttle" id="shuttle">
  <div class="wrap">
    <div class="shuttle-grid">
      <div class="reveal">
        <p class="kicker">{escape(shuttle['kicker'])}</p>
        <h2>{title}</h2>
        <p class="section-lead">{escape(shuttle['body'])}</p>
      </div>
      <div class="route-card reveal" data-shuttle>
        <div class="route-title"><span>{render_icon('shuttle', 18)} {escape(shuttle['route_title'])}</span><span class="route-badge">{escape(shuttle['route_badge'])}</span></div>
        <ol class="route-line"><span class="route-fill" data-route-fill></span>{stops}</ol>
        <div class="route-alert" data-route-alert>{render_icon('vibrate', 16)} {escape(shuttle['alert'])}</div>
      </div>
    </div>
    <div class="use-grid">{uses}</div>
  </div>
</section>
"""


def render_home_page(language_code):
    copy = content.load_home_copy(language_code)
    page_path = content.home_path(language_code)
    root = content.relative_root(page_path)
    page_url = content.SITE_URL + page_path
    alternates = {code: content.home_path(code) for code in content.LANGUAGE_CODES}
    page = {
        "language": language_code, "path": page_path, "alternates": alternates,
        "title": copy["meta"]["title"], "description": copy["meta"]["description"], "keywords": copy["meta"]["keywords"],
        "schemas": [
            build_mobile_application_schema(language_code, page_url),
            build_faq_schema(copy["faq"]["items"]),
            build_breadcrumb_schema([(copy["meta"]["app_name"], page_url)]),
        ],
    }
    return (render_head(page, root) + render_nav(language_code, root, alternates)
            + '<main id="main">\n'
            + render_hero(copy, language_code, root)
            + render_arrive_section(copy, language_code, root)
            + render_shuttle_section(copy)
            + render_how_section(copy, language_code, root)
            + render_features_section(copy, language_code, root)
            + render_guides_section(copy, language_code, root)
            + render_faq_section(copy)
            + render_final_section(copy, language_code, root)
            + "</main>\n" + render_footer(language_code, root))

