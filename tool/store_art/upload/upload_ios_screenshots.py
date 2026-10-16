import sys
sys.path.insert(0,'/Users/suhsaechan/Desktop/Programming/project/EarLocAlert/tool/store_art/upload')
from browser_page import with_page
lang=sys.argv[1]   # ko·en·ja·zh — 먼저 화면에서 그 언어로 전환해 둔다
root='/Users/suhsaechan/Desktop/Programming/project/EarLocAlert/docs/store/promo/'+lang+'/ios-6.3/'
files=[root+f'0{i}.png' for i in range(1,7)]
def act(page):
    page.locator('input[type=file]').first.set_input_files(files)
    page.wait_for_timeout(15000)
    print(page.evaluate("()=>document.body.innerText.match(/\\d+개 중 \\d+개의 앱 스크린샷/g)"))
with_page('appstoreconnect', act)
