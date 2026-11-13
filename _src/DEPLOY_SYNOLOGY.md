# 이어폰위치알림 소개 사이트 — 생성·시놀로지 배포 (earlocalert.suhsaechan.kr)

## 사이트 생성

gh-pages 작업 트리 루트에서:

```bash
python3 -I _src/build_site.py                                   # github.io 기준, 이 브랜치 루트에 덮어쓰기
python3 -I _src/build_site.py --out /tmp/site --custom-domain   # 보유 도메인 기준, 별도 폴더 (시놀로지용)
python3 _src/build_shots.py <앱 레포 경로>                        # 앱 화면 캡처 갱신 (Pillow 필요, 캡처를 바꿨을 때만)
```

| 고칠 것 | 원본 |
|---|---|
| 랜딩 문구 (언어별) | `_src/copy/{ko,en,ja,zh}.json` |
| 정보 글 (언어별 4편) | `_src/copy/guides.{ko,en,ja,zh}.json` — slug 는 `site_content.GUIDE_SLUGS` |
| 주소·스토어 링크·도메인 스위치·app-ads.txt | `_src/site_content.py` |
| 개인정보 처리방침·이용약관 본문 | `_src/hand_managed/*.html` (본문 `<main class="doc">` 만 새 틀에 그대로 담음) |
| 디자인 · 연출 | `style.css` · `site.js` (바꾸면 `site_head.ASSET_VERSION` 올림) |

생성 결과(`index.html`·`en.html`·`guide/`·`en/guide/` 등)는 손으로 고치지 않는다. 다음 생성 때 덮어써진다.

## 서빙 구조

```
브라우저 > Cloudflare DNS (CNAME, DNS 전용) > NAS DDNS 주소(pro-launch 자격 `synology-chan4760` 의 host)
  > DSM 리버스 프록시 (80·443) > Traefik localhost:8079 > 컨테이너 earlocalert-site (nginx:1.27-alpine :80)
```

passql-site 와 같은 경로다. 호스트 포트를 새로 열지 않는다.

| 구성 | 값 |
|---|---|
| DNS · DSM 리버스 프록시 · 인증서 | `earlocalert`·`www.earlocalert` 443·80 > `http://localhost:8079` (준비됨) |
| Traefik 라우터 | `earlocalert-site`: ``Host(`earlocalert.suhsaechan.kr`) || Host(`www.earlocalert.suhsaechan.kr`)`` (compose 라벨) |
| NAS 폴더 | `/volume1/projects/earlocalert/site/` — `html/`(사이트), `nginx.conf`, `security-headers.inc`, `docker-compose.yml` |
| 원본 | `_src/synology/` (설정), `_src/site_verification/` (검색엔진 소유 확인 파일, 받으면 추가) |

nginx 가 처리하는 것: www > 루트 301, http > https 301, 404 > `/404.html`, gzip,
캐시(HTML 5분 · robots/sitemap/app-ads 1시간 · css/js/이미지/영상 7일), 보안 헤더.
HTTPS 종료와 HSTS 는 DSM 443 규칙이 맡는다.

## 배포

```bash
bash _src/synology/deploy_synology.sh
```

1. `--out <임시폴더> --custom-domain` 으로 보유 도메인 기준 사이트 생성 (`app-ads.txt` 포함)
2. `_src/site_verification/*.html` 복사 (있으면)
3. tar 묶음을 ssh 로 보내 NAS 에서 풀고 `html/` 을 NAS 로컬 `rsync --delete` 로 맞춤
4. 공개 주소 상태 코드 출력

**첫 배포**는 업로드 뒤 NAS 에서 컨테이너를 띄운다:

```bash
cd /volume1/projects/earlocalert/site && sudo /usr/local/bin/docker compose -p earlocalert-site up -d
```

이후 내용만 바꾸면 재시작이 필요 없다(읽기 전용 바인드 마운트). nginx.conf 만 바꿨으면
`sudo /usr/local/bin/docker exec earlocalert-site nginx -t && sudo /usr/local/bin/docker exec earlocalert-site nginx -s reload`.

## 확인

```bash
curl -sI https://earlocalert.suhsaechan.kr/                                # 200
curl -sI https://earlocalert.suhsaechan.kr/guide/shuttle-bus-stop-alert/   # 200
curl -s  https://earlocalert.suhsaechan.kr/app-ads.txt                     # google.com, pub-..., DIRECT, ...
curl -sI https://earlocalert.suhsaechan.kr/없는주소                          # 404 (404.html 본문)
curl -sI https://www.earlocalert.suhsaechan.kr/                            # 301 > https://earlocalert.suhsaechan.kr/
```

## 옛 주소(github.io) 넘기기 — 새 주소가 확인된 뒤에

```bash
python3 -I _src/build_site.py --redirect-to https://earlocalert.suhsaechan.kr/
```

gh-pages 루트의 모든 페이지가 같은 경로의 새 주소로 넘기는 이동 페이지가 되고 sitemap 이 지워진다.
그 전에 스토어 등록정보의 웹사이트·개인정보처리방침 주소와 앱 안의 링크를 새 주소로 바꾼다
(AdMob 은 등록정보 웹사이트 도메인 루트의 `app-ads.txt` 를 읽는다 — docs/10-DECISIONS.md app-ads.txt 호스팅).

## 되돌리기

```bash
cd /volume1/projects/earlocalert/site && sudo /usr/local/bin/docker compose -p earlocalert-site down
```
