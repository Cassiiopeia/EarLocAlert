"""Play Console 기본 스토어 등록정보 편집기에서 지금 선택된 언어의 이미지를 교체한다 (#281)

    ~/.projectops/agent-test/.venv/bin/python tool/store_art/upload/upload_play_language.py <ko|en|ja|zh> [--delete-existing]

- 먼저 편집기에서 그 언어로 전환해 둔다 (기본 스토어 등록정보 편집 > 수정할 언어 선택)
- 그래픽 이미지 1장 + 휴대전화 스크린샷 6장(01~06)을 docs/store/promo/<lang>/ 의 이미지로 바꾼다
- --delete-existing: 기본 언어(ko)처럼 실제 애셋이 있는 칸을 먼저 지운다.
  다른 언어 칸은 기본 언어 애셋이 흐리게 보이는 상태라(삭제 버튼이 안 먹는다) 지우지 않고 새로 추가하면 대체된다
- 스토어에 노출되는 순서 = 애셋 보관함에서 선택한 클릭 순서다. 그래서 01~06 을 번호 순서로 하나씩 눌러 고른다
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from browser_page import with_page

lang = sys.argv[1]
SHOULD_DELETE_EXISTING = "--delete-existing" in sys.argv
PROMO = Path(__file__).resolve().parents[3] / "docs/store/promo" / lang
PHONE_NAMES = [f"0{i}.png" for i in range(1, 7)]
PHONE_FILES = [str(PROMO / "android-phone" / name) for name in PHONE_NAMES]
GRAPHIC_FILE = str(PROMO / "feature-graphic.png")
CLOSE_PANEL_XY = (2518, 168)  # 애셋 보관함 패널 닫기 버튼 (뷰포트 2560 기준)
MAX_DELETE_ATTEMPTS = 10

MARK_SECTION_JS = """(title)=>{
  const h=[...document.querySelectorAll('*')].find(e=>e.children.length==0 && (e.textContent||'').trim().startsWith(title));
  let p=h; for(let i=0;i<8;i++){p=p.parentElement; if(/애셋 추가/.test(p.innerText)) break;}
  p.setAttribute('data-section',title); return true;}"""
SELECTED_NAMES_JS = "()=>(document.body.innerText.match(/선택됨 애셋 [^\\n]*/g)||[]).map(s=>s.replace('선택됨 애셋 ',''))"


def selected_names(page):
    return page.evaluate(SELECTED_NAMES_JS)


def click_thumbnail(page, name):
    """보관함의 name 항목 썸네일을 누른다 (고정 헤더에 가리면 한 칸씩 내려서 다시)"""
    item = page.locator(f'text="{name}"').first
    item.evaluate("e=>e.scrollIntoView({block:'center'})")
    page.wait_for_timeout(400)
    box = item.bounding_box()
    page.mouse.click(box['x'] - 70, box['y'] + 25)
    page.wait_for_timeout(700)


def select_in_order(page, names):
    """선택을 모두 풀고 names 순서대로 하나씩 고른다 (노출 순서가 이 순서가 된다)"""
    for name in list(selected_names(page)):
        click_thumbnail(page, name)
    assert not selected_names(page), f"선택이 안 풀렸다: {selected_names(page)}"
    for name in names:
        before = len(selected_names(page))
        for _ in range(3):
            click_thumbnail(page, name)
            if len(selected_names(page)) > before:
                break
        else:
            raise SystemExit(f"{name} 선택이 안 된다")
    print('선택 완료', len(selected_names(page)), '장')


def close_panel_if_open(page):
    for _ in range(2):
        if page.locator('text=애셋 검색').count() and page.locator('text=애셋 검색').first.is_visible():
            page.mouse.click(*CLOSE_PANEL_XY)
            page.wait_for_timeout(800)


def replace_assets(page, title, names, files):
    close_panel_if_open(page)
    page.evaluate(MARK_SECTION_JS, title)
    section = page.locator(f'[data-section="{title}"]')
    section.evaluate("e=>e.scrollIntoView({block:'center'})")
    page.wait_for_timeout(500)
    if SHOULD_DELETE_EXISTING:
        delete_buttons = section.locator('button:has-text("delete")')
        for _ in range(MAX_DELETE_ATTEMPTS):
            if not delete_buttons.count():
                break
            delete_buttons.first.evaluate('e=>e.click()')  # 고정 헤더가 좌표 클릭을 가로채서 JS 로 누른다
            page.wait_for_timeout(1200)
    section.get_by_role('button', name='애셋 추가').evaluate('e=>e.click()')
    page.wait_for_timeout(3000)
    page.locator('input[type=file]').first.set_input_files(files)
    page.wait_for_timeout(8000 + 2500 * len(files))
    select_in_order(page, names)
    page.get_by_role('button', name='추가', exact=True).last.click()
    page.wait_for_timeout(4000)
    close_panel_if_open(page)
    labels = page.evaluate("(t)=>[...document.querySelector(`[data-section=\"${t}\"]`).querySelectorAll('button')].map(b=>b.getAttribute('aria-label')||'').filter(s=>s.endsWith('삭제'))", title)
    print(title, '→', labels)


def act(page):
    replace_assets(page, '그래픽 이미지', ['feature-graphic.png'], [GRAPHIC_FILE])
    replace_assets(page, '휴대전화 스크린샷', PHONE_NAMES, PHONE_FILES)


with_page('play.google.com/console', act)
