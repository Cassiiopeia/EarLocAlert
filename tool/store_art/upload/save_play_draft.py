"""Play Console 스토어 등록정보 편집기에서 '임시보관함에 저장'을 누른다 (#281) — 언어마다 진행을 남기려고"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from browser_page import with_page


def act(page):
    page.get_by_role('button', name='임시보관함에 저장').first.evaluate('e=>e.click()')
    page.wait_for_timeout(6000)
    print('임시 저장 완료')


with_page('play.google.com/console', act)
