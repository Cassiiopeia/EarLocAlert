# 디자인 시스템 재정립 — 라이트·다크 두 벌, Apple 결

- 날짜: 2026-10-15
- 상태: 승인됨 (대화에서 승인, 사용자 "싹다해줘")
- 관련: #268(장소 폼), #270(워치 안내), #271(디자인 요청)

## 목적

앱 전체를 iOS HIG 결(그룹형 목록, 계층별 배경, 얇은 선형 아이콘, 절제된 색)로 정리하고
라이트 모드를 더한다. 사용자가 설정에서 화면 모드를 고를 수 있어야 한다.

### 사용자가 정한 것

- 라이트 + 다크를 모두 지원한다. 설정에서 바꿀 수 있어야 한다.
- 주색은 민트로 바꾼다. 금색은 출발·경고로 내려간다.
- 세부 판단은 개발이 맡는다. 전부 진행한다.

### 유지하는 것 (바꾸지 않는다)

- Pretendard (이미 적용, #145)
- 알림 화면 규칙: 광고 금지, 해제 버튼 84px + 넓은 탭 범위, 스와이프 해제 금지
- 주 버튼은 한 화면에 한 자리 (`design_system_test`)
- 아이콘은 Material `_outlined` 만, 크기는 `AppIconSize` 토큰만
- 간격 8·16·24·40 (모두 4pt 배수 — Apple 4pt 체계와 맞는다)
- 그림자 없음, 층은 배경 명도로

## 1. 색 — 팔레트 두 벌

`AppPalette` (`ThemeExtension`) 를 라이트·다크 두 벌로 둔다. 화면은 `context.palette.x` 로 읽는다.

| 역할 | 다크 | 라이트 | 쓰는 곳 |
|---|---|---|---|
| `background` | `#000000` | `#F2F2F7` | 화면 바탕 |
| `surface` | `#1C1C1E` | `#FFFFFF` | 카드·시트·목록 묶음 |
| `elevated` | `#2C2C2E` | `#E5E5EA` | 카드 위 요소, 선택 안 된 칸 |
| `separator` | `#38383A` | `#C6C6C8` | 목록 행 사이 선 |
| `textPrimary` | `#FFFFFF` | `#1C1C1E` | 본문 |
| `textSecondary` | `#98989F` | `#6C6C70` | 보조 설명 |
| `accent` | `#6FE3D3` | `#0A7A6D` | 주 버튼, 선택, 도착, 감시 중 |
| `onAccent` | `#000000` | `#FFFFFF` | 주 버튼 글자 |
| `warning` | `#F2B85B` | `#8F5C0E` | 출발, 감시 중지 |
| `onWarning` | `#000000` | `#FFFFFF` | 금색 바탕 위 글자 |
| `danger` | `#FF453A` | `#E5484D` | 삭제만 |

의미 색(`AppSemanticColors`)은 팔레트에서 파생한다:
`alertEnter = accent`, `alertExit = warning`, `statusActive = accent`,
`statusInactive = warning`, `audioBluetooth = accent`.

`AppColors` 정적 상수는 **다크 팔레트 값을 담는 내부 정의**로만 남긴다. `lib/features/**` 와 `lib/core/widgets/**`
에서 `AppColors.` 를 쓰면 `design_system_test` 가 실패한다. 예외: 알림 화면처럼 항상 다크인 곳도
`context.palette` 를 쓴다(테마로 다크를 강제하므로 같은 값이 나온다).

## 2. 글자

- `AppTypography` 의 스타일에서 `color` 를 뺀다. 색은 `DefaultTextStyle`(테마 `onSurface`)이 정한다.
- 보조 설명은 `context.typo.caption` 이 `textSecondary` 를 입혀 돌려준다.
  `AppTypography.caption` 을 화면에서 직접 쓰면 회색이 빠지므로, 화면은 `context.typo.*` 만 쓴다.
- 크기는 유지(본문 16, 보조 14, 화면 제목 24, 수치 32, 알림 장소명 48). 목록 행 제목용 `headline` 17 SemiBold 추가.

## 3. 컴포넌트 (`lib/core/widgets/`)

| 컴포넌트 | 내용 |
|---|---|
| `GroupedSection` | iOS 설정 앱식 묶음. 머리글(보조색 caption) + `surface` 둥근 카드(반경 16) + 행 사이 `separator` 선(왼쪽 들여쓰기) |
| `AppSegmentedControl<T>` | 트랙(`elevated`) 위 선택 칸만 `surface`(다크)/흰색(라이트)으로 떠오르는 iOS 세그먼트. 아이콘 + 라벨 |
| 입력창 | `InputDecorationTheme`: 채움(`surface`), 반경 12→16 토큰, 포커스 시 `accent` 테두리 |
| 버튼 | 주 버튼 `accent` 캡슐. 보조는 `elevated` 바탕 캡슐(`FilledButton.tonal` 대신 `TextButton` 스타일) |
| 시트 | 손잡이 표시, 상단 반경 24, `surface` |

도착/출발/둘 다 아이콘: `where_to_vote_outlined` / `near_me_outlined` / `sync_alt_outlined`.

## 4. 화면 모드 설정

- `AppThemePreference { system, light, dark }` — SharedPreferences `app.theme_mode`, 기본 `system`.
- Riverpod 컨트롤러(`@riverpod`), `MaterialApp.themeMode` 에 연결.
- 설정 > 일반 > "화면 모드" 줄 → 시트에서 고르면 즉시 적용·저장, 되돌리기 스낵바.
- 상태바: `AppBarTheme.systemOverlayStyle` 을 밝기별로.
- 로그: `[settings] theme mode changed from=… to=…` (영어, Diagnostics).

## 5. 예외

- **알림 화면은 항상 다크.** 라우트 빌더에서 `Theme(data: AppTheme.dark())` 로 감싼다. 알림 화면 지도도 다크 스타일.
- 다른 지도(홈·위치 선택·폼 미리보기)는 밝기에 맞춰 `MapStyle.dark` / `MapStyle.light`.
- 네이티브 스플래시·네이티브 알림은 범위 밖.

## 6. 단계

1. **기반** — 팔레트·테마 두 벌, 글자 색 분리, 화면 모드 설정, 사용처 이전, 라이트 지도 스타일, 알림 화면 다크 고정.
   다크 화면은 거의 그대로여야 한다(주색만 민트로).
2. **컴포넌트 + 장소 폼 + 설정** — `GroupedSection`, `AppSegmentedControl`, 입력창 테마 적용.
3. **나머지 화면** — 홈 시트·카드, 온보딩, 진단, 알림음 시트 등 나머지 화면에 같은 규칙을 적용.

## 검증

- `flutter analyze` 무경고, 전체 테스트 통과.
- `design_system_test` 에 추가: 화면 코드의 `AppColors.` 금지, `AppTypography.*` 직접 사용 금지.
- 테마 테스트: 라이트·다크 각각에서 본문 글자색과 배경 대비가 4.5:1 이상(본문), 주 버튼 글자 3:1 이상.
- 알림 화면이 라이트 설정에서도 다크로 그려지는지 위젯 테스트.
- 화면 모드 저장·복원 테스트.
- 라이트·다크 시뮬레이터 캡처로 눈 확인.

## 문서

- `docs/06-UX.md` 디자인 시스템 절(색·타이포·형태·하지 않는 것) 갱신.
- `docs/10-DECISIONS.md` 에 결정 추가: 라이트 모드 도입, 주색 민트, 알림 화면 다크 고정.
