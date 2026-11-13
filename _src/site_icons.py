# -*- coding: utf-8 -*-
"""인라인 SVG 아이콘 (이모지 대신: 기기·폰트마다 모양이 달라 디자인이 흔들림 방지)
선 아이콘은 stroke=currentColor > 글자색을 따라감
"""

# 선 아이콘 공통 속성
_STROKE_ATTRIBUTES = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'

ICON_PATHS = {
    "vibrate": '<rect x="7" y="4" width="10" height="16" rx="2"/><path d="M3 9v6M21 9v6"/>',
    "radius": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/>',
    "earphone": '<path d="M3 14v-2a9 9 0 0 1 18 0v2"/><path d="M21 15a2 2 0 0 1-2 2h-1v-6h1a2 2 0 0 1 2 2zM3 15a2 2 0 0 0 2 2h1v-6H5a2 2 0 0 0-2 2z"/>',
    "shuttle": '<rect x="3" y="5" width="18" height="12" rx="3"/><path d="M3 11h18M7 17v2M17 17v2"/><circle cx="7.5" cy="14" r=".6"/><circle cx="16.5" cy="14" r=".6"/>',
    "bus": '<rect x="5" y="3" width="14" height="15" rx="3"/><path d="M5 10h14M8 18v2M16 18v2"/><circle cx="8.5" cy="14.5" r=".6"/><circle cx="15.5" cy="14.5" r=".6"/>',
    "office": '<path d="M4 21V5l8-3 8 3v16"/><path d="M9 21v-4h6v4M9 8h.01M15 8h.01M9 12h.01M15 12h.01"/>',
    "school": '<path d="m2 9 10-5 10 5-10 5z"/><path d="M6 11v5c0 1.5 2.7 3 6 3s6-1.5 6-3v-5"/>',
    "plane": '<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
    "check": '<path d="m5 12 5 5 9-10"/>',
    "lock": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    "speaker_off": '<path d="M11 5 6 9H2v6h4l5 4z"/><path d="m23 9-6 6M17 9l6 6"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    "chevron_down": '<path d="m6 9 6 6 6-6"/>',
    "arrow_right": '<path d="M5 12h14M13 6l6 6-6 6"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
}

# 채운 로고 (스토어 상표 모양 > 스토어 버튼에만)
APPLE_LOGO = '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.6c0-2.5 2.1-3.7 2.2-3.8-1.2-1.7-3-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8s2 .8 3.4.8 2.2-1.3 3.1-2.5c1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.2zM13.9 5.2c.7-.9 1.2-2 1-3.2-1 0-2.3.7-3 1.6-.7.8-1.2 2-1.1 3.1 1.2.1 2.3-.6 3.1-1.5z"/></svg>'
PLAY_LOGO = '<svg width="18" height="20" viewBox="0 0 24 26" fill="currentColor" aria-hidden="true"><path d="M1 1.5v23l12-11.5zM14.5 14.4l3 2.9-13 7.4zM14.5 11.6l-10-10.3 13 7.4zM19 10l3.4 2c.8.5.8 1.5 0 2L19 16l-3.3-3z"/></svg>'


def render_icon(icon_name, size_pixels=20):
    """아이콘 이름 > 인라인 SVG (장식용, 화면 낭독기에서 숨김)"""
    return (f'<svg class="icon" width="{size_pixels}" height="{size_pixels}" viewBox="0 0 24 24" '
            f'{_STROKE_ATTRIBUTES} aria-hidden="true">{ICON_PATHS[icon_name]}</svg>')
