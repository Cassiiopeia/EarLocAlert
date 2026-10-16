"""Play Console 기본 스토어 등록정보 편집기의 '수정할 언어'를 바꾼다 (#281)

    ~/.projectops/agent-test/.venv/bin/python tool/store_art/upload/switch_play_language.py "한국어"
    (라벨: 한국어 · 영어(미국) · 일본어 · 중국어(간체) 처럼 드롭다운에 보이는 앞부분)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from browser_page import with_page

label = sys.argv[1]


def act(page):
    page.mouse.click(2518, 168) if page.locator('text=애셋 검색').count() and page.locator('text=애셋 검색').first.is_visible() else None
    page.wait_for_timeout(500)
    page.evaluate("()=>window.scrollTo(0,0)")
    page.locator('button[aria-haspopup="listbox"]').first.click()
    page.wait_for_timeout(800)
    # 목록 항목은 role=option 이 아니라 글자만 있다 ('한국어 – ko-KR' 처럼)
    page.get_by_text(label, exact=False).filter(has_text=' – ').first.click()
    page.wait_for_timeout(5000)
    print(page.locator('button[aria-haspopup="listbox"]').first.inner_text().replace('\n', ' '))


with_page('play.google.com/console', act)
