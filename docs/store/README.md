# 스토어 자산

Google Play 스토어 등록정보에 올리는 이미지와 그 원본이다.

| 파일 | 규격 | 쓰는 곳 |
|---|---|---|
| `app-icon-512.png` | 512 x 512 | Play Console 앱 아이콘 |
| `feature-graphic.png` | 1024 x 500 | Play Console 그래픽 이미지 |
| `source-app-icon.png` | 1254 x 1254 | 위 둘의 원본 |
| `source-feature-graphic.png` | 1794 x 876 | 그래픽 이미지 원본 |

## 앱 아이콘을 바꿀 때

`source-app-icon.png` 를 교체한 뒤 아래를 만들어 `assets/icon/` 에 넣는다.

- `app_icon.png` — 1024 x 1024, 배경 포함. 레거시 아이콘과 iOS 가 쓴다
- `app_icon_foreground.png` — 1024 x 1024, **배경을 지우고 핀만** 남긴 이미지

**전경에서 배경을 지워야 하는 이유** — Android 12+ 는 적응형 아이콘에 원형·둥근사각형 마스크를 씌운다. 배경이 포함된 이미지를 그대로 전경으로 쓰면 사각 모서리가 잘리고 핀이 밀린다.

**핀의 실제 크기를 기준으로 맞춘다.** 원본은 캔버스 안에 여백을 두고 그려져 있어서, 캔버스째 줄이면 여백까지 함께 줄어 런처에서 유독 작아 보인다. 알파 채널의 경계 상자를 구해 그 영역이 캔버스의 약 72%(적응형 아이콘 안전 영역)를 차지하도록 맞춘다.

`pubspec.yaml` 의 `adaptive_icon_background` 는 **원본 배경색과 같아야 한다.** 어긋나면 마스크 가장자리에 다른 색이 비친다.

생성:

```
dart run flutter_launcher_icons
```

## 그래픽 이미지 주의

**"Get it on Google Play" 배지를 넣지 않는다.** 그 배지는 Play 밖에서 앱을 홍보할 때 쓰는 것이고, 메타데이터 정책의 "Google Play 프로그램을 나타내는 요소" 조항에 걸릴 소지가 있다 (docs/09-RELEASE.md).


## 플랫폼별 등록정보는 따로 쓴다 (이슈 #244, #245)

Android 와 iOS 는 알림이 다르게 동작하므로 설명문을 나눈다.

| | Android (`ko-KR_full.txt`) | iOS (`ios-ko-KR_full.txt`) |
|---|---|---|
| 앱을 밀어서 종료 | 그래도 동작한다고 쓴다 | 위치 감시가 멈춰 알림이 늦거나 오지 않을 수 있다고 쓴다 |
| 필요한 권한 | 위치(항상), 알림, 배터리 최적화 제외, 다른 앱 위에 표시, 전체 화면 알림 | 위치(항상), 알림, 잠금화면 알람(iOS 26+) |
| 백그라운드 알림 | 알림 화면이 자동으로 뜬다 | 알림과 진동. 알림 화면은 앱을 열어야 보인다 |

- 간단한 설명(Play) 80자: `ko-KR_short.txt`, 프로모션 텍스트(App Store) 170자: `ios-ko-KR_promo.txt`
- 스크린샷은 `screenshots/ko-KR/` (Android 에뮬레이터). iOS 스크린샷은 iOS 시뮬레이터에서 따로 찍는다
