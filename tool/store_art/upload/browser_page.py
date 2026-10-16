"""실행 중인 pro-launch 브라우저(CDP)에 붙어 스토어 콘솔 페이지를 돌려준다 (#281)

pro-launch 의 `web` 명령에는 파일 업로드가 없어서, 같은 브라우저(로그인 유지)에 직접 붙는다.
Playwright 는 pro-launch 가 쓰는 가상환경(~/.projectops/agent-test/.venv)에 있다.
"""
import json
import os
from pathlib import Path

from playwright.sync_api import sync_playwright

BROWSER_STATE_FILE = Path.home() / ".projectops/launch/Cassiiopeia__EarLocAlert/browser.json"


def open_console_page(playwright, url_keyword):
    """주소에 url_keyword 가 든 탭을 찾아 돌려준다 (없으면 None)"""
    cdp_url = json.loads(BROWSER_STATE_FILE.read_text())["cdp"]
    browser = playwright.chromium.connect_over_cdp(cdp_url)
    for context in browser.contexts:
        for page in context.pages:
            if url_keyword in page.url:
                return page
    return None


def with_page(url_keyword, action):
    with sync_playwright() as playwright:
        page = open_console_page(playwright, url_keyword)
        if page is None:
            raise SystemExit(f"{url_keyword} 탭을 찾지 못했다")
        return action(page)
