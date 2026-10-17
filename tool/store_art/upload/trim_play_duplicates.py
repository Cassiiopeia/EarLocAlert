"""Play Console 편집기에서 지금 언어의 그래픽(1장)·휴대전화 스크린샷(6장)이 넘치면 뒤쪽 중복분을 지운다 (#281)

중단된 업로드의 사본이 임시 저장돼 있다가 새 업로드와 겹치면 12/8, 2/1 처럼 한도를 넘어 저장이 막힌다.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from browser_page import with_page

KEEP_COUNT_BY_SECTION = {'그래픽 이미지': 1, '휴대전화 스크린샷': 6}
MARK_JS = """(title)=>{
  const h=[...document.querySelectorAll('*')].find(e=>e.children.length==0 && (e.textContent||'').trim().startsWith(title));
  let p=h; for(let i=0;i<8;i++){p=p.parentElement; if(/애셋 추가/.test(p.innerText)) break;}
  p.setAttribute('data-section',title);}"""


def act(page):
    if page.locator('text=애셋 검색').count() and page.locator('text=애셋 검색').first.is_visible():
        page.mouse.click(2518, 168)
        page.wait_for_timeout(800)
    for title, keep in KEEP_COUNT_BY_SECTION.items():
        page.evaluate(MARK_JS, title)
        deletes = page.locator(f'[data-section="{title}"] button[aria-label$="삭제"]')
        for _ in range(20):
            if deletes.count() <= keep:
                break
            deletes.last.evaluate('e=>e.click()')  # 뒤쪽(중복) 것부터
            page.wait_for_timeout(1200)
        print(title, '남은 수', deletes.count(), '(목표', keep, ')')


with_page('play.google.com/console', act)
