# 공통 UI 컴포넌트 계층 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 디자인 시스템을 `lib/core/ui/` 한 계층으로 모으고, 바텀시트·목록 행·칸 제목을 공통 컴포넌트로 바꾸며, 이름을 직관적으로 정비한다.

**Architecture:** 기존 `core/theme`·`core/widgets` 를 `core/ui/foundation`·`core/ui/components` 로 옮기고 식별자를 바꾼다(기계적 치환 + analyze). 새 컴포넌트는 TDD 로 만든 뒤 화면을 하나씩 옮긴다. 규칙 테스트로 되돌아가지 못하게 막는다.

**Tech Stack:** Flutter 3.35.5 (`~/development/flutter-3.35.5/bin`), Riverpod codegen.

**Spec:** `docs/superpowers/specs/2026-10-15-ui-component-layer-design.md`

## Global Constraints

- 동작 변경 없음 — 화면 문구·탭 대상·로그는 그대로.
- 이름은 spec §2 표 그대로. 새 이름도 역할이 드러나게.
- 아이콘 `_outlined`, 크기 `AppIconSize`, 간격 8·16·24·40, 주 버튼(FilledButton) 위젯 클래스당 1개.
- 커밋: 이슈 #276, 경로 명시 스테이징, Co-Authored-By 금지.

## Review Focus

- 시트 안 `TextField` 가 있는 시트(문제 신고·시간대)에서 키보드가 올라와도 내용이 가려지지 않는지 — `BottomSheetWithHeaderLayout` 이 `viewInsets` 를 반영해야 한다.
- 글자 200% 에서 모든 시트가 넘치지 않고 스크롤되는지.
- `GroupedListRow.toggle` 의 스위치와 행 탭이 같은 동작인지(행 어디를 눌러도 토글).
- 옮긴 뒤 기존 위젯 테스트의 finder(문구)가 그대로 맞는지.
- 라이트 모드에서 눌림 물결이 둥근 카드 밖으로 새지 않는지.

---

### Task 1: 계층 이동 · 이름 바꾸기
- `git mv lib/core/theme lib/core/ui/foundation`, `git mv lib/core/widgets lib/core/ui/components`, `app_feedback.dart` → `lib/core/ui/feedback/`.
- 파일명: `app_palette.dart`→`app_color_palette.dart`, `grouped_section.dart`→`grouped_list_section.dart`, `app_segmented_control.dart`→`icon_label_segmented_control.dart`, `themed_status_bar.dart`→`status_bar_icons_following_theme.dart`, `lib/app/alert_theme.dart`→`lib/app/always_dark_alert_theme.dart`. 테스트 파일도 같은 규칙.
- 식별자 치환(spec §2). import 경로 일괄 치환. `build_runner` 재생성.
- 검증: `flutter analyze` 무경고, 전체 테스트 통과 → 커밋.

### Task 2: `BottomSheetWithHeaderLayout` + `showAppBottomSheet`
- 테스트 먼저(`test/core/ui/components/bottom_sheet_with_header_layout_test.dart`): 제목·설명·아이콘 표시 / 주 버튼 표시 / 글자 200% 에서 overflow 예외 없음 / 키보드(viewInsets 300) 에서 본문이 그 위로 올라옴.
- 구현 후 시트 9개를 옮긴다. 각 시트 기존 테스트 통과 확인 → 커밋.

### Task 3: `GroupedListRow` · `SectionTitleWithTrailingValue`
- 테스트 먼저: navigation 탭 콜백·화살표 / toggle 행 탭 = 스위치 변경 / value 오른쪽 값 / selectable 체크 / enabled false 무반응.
- 설정 화면(`_SettingTile`·`_PermissionTile`·버전 줄), 장소 폼 소리 칸, 알림음 선택 목록, `PlaceSectionLabel` 사용처를 옮긴다 → 커밋.

### Task 4: 규칙 테스트
- `design_system_test`: features 의 `showModalBottomSheet(`·`ListTile(` 금지(허용 목록 명시), `core/ui` 의 features·app import 금지, 기존 색·글자 규칙의 경로 갱신 → 커밋.

### Task 5: 아키텍처 검수 반영
- 검수 보고의 높음·중간 항목 중 이 작업과 같은 성격을 고친다. 나머지는 이슈로 남긴다 → 커밋.

### Task 6: 문서 · 검증 · 푸시
- 02-ARCHITECTURE, 06-UX, 10-DECISIONS 066, CLAUDE.md. 시뮬레이터 캡처 회귀 확인. 커밋·푸시.
