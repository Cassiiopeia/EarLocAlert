# 공통 UI 컴포넌트 계층 — 설계

- 날짜: 2026-10-15
- 상태: 승인됨 (대화에서 승인)
- 이슈: #276 · 선행: #272 (라이트·다크 팔레트)

## 목적

#272 로 색·글자 체계는 공통화됐다. 그러나 화면 조각(바텀시트 틀, 목록 한 줄, 칸 제목)은 화면마다 손으로 짜고 있다.
디자인 시스템을 한 계층으로 모으고, 화면(features)은 그 계층의 부품만 조립하게 한다. 새 화면도 자동으로 같은 결을 따르게
규칙 테스트로 강제한다.

## 명명 원칙

**길어도 이름만 보고 무엇인지 알 수 있게 짓는다** (사용자 요청). 줄임말과 역할이 드러나지 않는 이름을 쓰지 않는다.

## 1. 계층 — `lib/core/ui/`

```
core/ui/
  foundation/   app_color_palette · app_text_styles(typography) · app_spacing · app_theme
                app_theme_preference · app_theme_controller · app_semantic_colors · map_style · app_colors
  components/   bottom_sheet_with_header_layout · grouped_list_section · grouped_list_row
                section_title_with_trailing_value · icon_label_segmented_control
                floating_circle_button · status_bar_icons_following_theme · hit_slop
  feedback/     app_feedback (토스트 · 확인 창)
```

- `lib/core/theme/` → `lib/core/ui/foundation/`, `lib/core/widgets/` → `lib/core/ui/components/` 로 옮긴다(`git mv`).
- `features/*/presentation` 은 `core/ui` 의 부품을 조립한다. Material 원본(`showModalBottomSheet`, `ListTile`)을 직접 쓰지 않는다.
- `core/ui` 는 `features`·`app` 을 import 하지 않는다.

## 2. 이름 바꾸기

| 지금 | 바꿀 이름 |
|---|---|
| `AppPalette` | `AppColorPalette` |
| `context.palette` | `context.appColors` |
| `AppTextStyles` / `context.typo` | `AppTextStyles` / `context.appTextStyles` |
| `GroupedSection` | `GroupedListSection` |
| `AppSegmentedControl` / `AppSegment` | `IconLabelSegmentedControl` / `IconLabelSegment` |
| `ThemedStatusBar` | `StatusBarIconsFollowingTheme` |
| `alertTheme()` / `alertEmptyPlaceholder()` | `wrapWithAlwaysDarkAlertTheme()` / `alwaysDarkEmptyAlertPlaceholder()` |
| `MapStyle.forBrightness` | `MapStyle.jsonForBrightness` |
| `PlaceSectionLabel` (places) | `SectionTitleWithTrailingValue` (core/ui) |

## 3. 새 컴포넌트

### `showAppBottomSheet<T>` + `BottomSheetWithHeaderLayout`

```dart
Future<T?> showAppBottomSheet<T>(BuildContext context, {required WidgetBuilder builder});

BottomSheetWithHeaderLayout(
  headerIcon: Icons.contrast_outlined,   // 선택
  title: '화면 모드',
  description: '알림 화면은 항상 어둡게 보여요.',  // 선택
  body: ...,                              // 스크롤된다
  primaryAction: FilledButton(...),        // 선택 — 아래 한 자리
  secondaryAction: TextButton(...),        // 선택 — 주 버튼 아래
)
```

- 손잡이·상단 둥근 모서리·`isScrollControlled`·안전 영역·키보드 높이·스크롤을 한 곳에서 처리한다.
- 설명은 `keepAllText` 를 거친다.
- 머리 아이콘·제목 굵기·여백(좌우 24, 아래 24)이 모든 시트에서 같아진다.

### `GroupedListRow`

```dart
GroupedListRow.navigation(icon:, title:, subtitle:, onTap:)          // 오른쪽 화살표
GroupedListRow.toggle(icon:, title:, subtitle:, value:, onChanged:)   // 스위치
GroupedListRow.value(icon:, title:, valueText:, onTap:)               // 오른쪽 값
GroupedListRow.selectable(icon:, title:, subtitle:, selected:, onTap:)// 체크
```

- 아이콘은 보조색, 제목은 본문, 부제는 보조색 caption(`keepAllText`).
- 눌림 피드백은 묶음 카드 안에서만 번진다(`GroupedListSection` 이 잘라 낸다).
- `enabled: false` 면 흐려지고 눌리지 않는다.

### `SectionTitleWithTrailingValue`

칸 위 회색 제목 + 오른쪽 굵은 값(선택). 장소 폼의 반경·알림 시점 칸 제목에 쓴다.

## 4. 적용 범위

- 바텀시트 9개(언어 · 화면 모드 · 워치 안내 · 진동 시험 · 알림음 크기 · 진동 세기 · 시간대 · 알림음 선택 · 문제 신고)를
  `BottomSheetWithHeaderLayout` 으로.
- 설정 화면 행 → `GroupedListRow`. 장소 폼 소리 칸 → `GroupedListRow.toggle` / `.navigation`. 알림음 선택 목록 → `.selectable`.
- 동작은 바꾸지 않는다. 기존 테스트가 안전망이다(문구·탭 대상이 같아야 한다).
- 아키텍처 검수에서 나온 위반 중 이 계층 정리와 같은 성격(중복·이름·죽은 코드·계층 위반)은 함께 고친다.

## 5. 규칙 테스트 (`design_system_test`)

- `lib/features/**` 에서 `showModalBottomSheet(` 금지 → `showAppBottomSheet` 만.
- `lib/features/**` 에서 `ListTile(` 금지. 예외는 테스트에 목록으로 둔다(라디오 선택 `RadioListTile` 은 허용).
- `lib/core/ui/**` 가 `features`·`app` 을 import 하지 않는다.
- 기존 규칙(`AppColors.`·`AppTypography.` 화면 직접 사용 금지)은 새 경로로 유지.

## 6. 문서

- `docs/02-ARCHITECTURE.md`: "디자인 시스템 계층" 절.
- `docs/06-UX.md`: 컴포넌트 목록과 언제 무엇을 쓰는지.
- `docs/10-DECISIONS.md` 066.
- `CLAUDE.md` 현재 상태 단락의 이름 갱신.

## 검증

- `flutter analyze` 무경고, 전체 테스트 통과(새 컴포넌트 위젯 테스트 포함).
- iOS 시뮬레이터에서 바텀시트 9개와 설정·폼을 라이트·다크로 캡처해 회귀가 없는지 본다.
