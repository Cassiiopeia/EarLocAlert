# 디자인 시스템 재정립 · 라이트 모드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 라이트·다크 팔레트 두 벌과 화면 모드 설정을 도입하고, Apple 결의 공용 컴포넌트로 모든 화면을 정리한다.

**Architecture:** 색은 `AppPalette`(ThemeExtension) 두 벌을 `AppTheme.light()/dark()` 에 싣고 화면은 `context.palette` 로 읽는다. 글자 스타일은 색을 빼고 `context.typo` 가 보조색을 입힌다. 화면 모드는 언어 설정과 같은 구조(SharedPreferences store + `@riverpod` 컨트롤러 + main 에서 초기값 주입)다.

**Tech Stack:** Flutter 3.35.5 (`~/development/flutter-3.35.5/bin`), Riverpod codegen, SharedPreferences, google_maps_flutter.

**Spec:** `docs/superpowers/specs/2026-10-15-design-system-light-dark-design.md`

## Global Constraints

- 색 값은 spec 표 그대로 (다크 `background #000000` … 라이트 `accent #0F9D8C` 등).
- `lib/features/**`, `lib/core/widgets/**` 에서 `AppColors.` · `AppTypography.` 직접 사용 금지 (테스트로 강제).
- 아이콘 `_outlined` 만, 크기 `AppIconSize` 토큰만, 간격 8·16·24·40, 주 버튼(FilledButton) 위젯 클래스당 1개.
- 알림 화면은 항상 다크. 네이티브(Kotlin·Swift) 코드는 건드리지 않는다.
- 화면 문자열은 l10n 4개 언어(ko·en·ja·zh). 로그는 `Diagnostics.log` 영어 `[tag] event key=value`.
- `@riverpod` codegen 만. 코드 주석은 간결한 한국어(WHY).
- 커밋: 이슈 #272, `git add -A` 금지, Co-Authored-By 금지.

## Review Focus

- 라이트 모드에서 흰 바탕 위 흰 글자 — 색이 박힌 `TextStyle` 이 남은 곳. Task 3 의 `design_system_test` 규칙과 라이트 위젯 테스트로 막는다.
- 알림 화면이 라이트 설정에서 밝게 그려짐 — Task 2 위젯 테스트.
- 저장된 화면 모드 값이 깨졌거나 모르는 값 — `system` 으로 떨어져야 한다. Task 2 테스트.
- 라이트 모드 지도가 다크 스타일 그대로 — Task 3 에서 `mapStyleFor(brightness)` 테스트.
- 주 버튼 대비 부족(라이트 민트 + 흰 글자) — Task 1 대비 테스트(3:1 이상).

---

### Task 1: 팔레트 · 글자 · 테마 두 벌

**Files:**
- Create: `lib/core/theme/app_palette.dart`
- Modify: `lib/core/theme/app_colors.dart`, `app_semantic_colors.dart`, `app_typography.dart`, `app_theme.dart`, `map_style.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppPalette` (fields: `background, surface, elevated, separator, textPrimary, textSecondary, accent, onAccent, warning, onWarning, danger`), `AppPalette.dark`, `AppPalette.light`, `extension PaletteContext on BuildContext { AppPalette get palette; AppTextStyles get typo; }`, `AppTextStyles` (`alertPlaceName, displayLarge, screenTitle, alertTime, headline, body, caption`), `AppTheme.light()`, `AppTheme.dark()`, `AppSemanticColors.fromPalette(AppPalette)`, `MapStyle.light`, `MapStyle.forBrightness(Brightness)`.

- [ ] **Step 1: 실패하는 테스트** — `test/core/theme/app_theme_test.dart`

```dart
import 'package:ear_loc_alert/core/theme/app_palette.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/core/theme/map_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, p) in [('dark', AppPalette.dark), ('light', AppPalette.light)]) {
    test('$name 본문 대비 4.5:1 이상', () {
      expect(_contrast(p.textPrimary, p.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
    });
    test('$name 주 버튼 글자 대비 3:1 이상', () {
      expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(3));
      expect(_contrast(p.onWarning, p.warning), greaterThanOrEqualTo(3));
    });
  }

  test('테마마다 맞는 팔레트가 실린다', () {
    expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.light().brightness, Brightness.light);
  });

  testWidgets('context.typo.caption 은 보조색이다', (tester) async {
    late TextStyle caption;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (c) { caption = c.typo.caption; return const SizedBox(); }),
    ));
    expect(caption.color, AppPalette.light.textSecondary);
  });

  test('밝기별 지도 스타일', () {
    expect(MapStyle.forBrightness(Brightness.dark), MapStyle.dark);
    expect(MapStyle.forBrightness(Brightness.light), MapStyle.light);
  });
}
```

- [ ] **Step 2:** `flutter test test/core/theme/app_theme_test.dart` → FAIL (`app_palette.dart` 없음)
- [ ] **Step 3: 구현**
  - `app_palette.dart`: `@immutable class AppPalette extends ThemeExtension<AppPalette>` — spec 표 값으로 `dark`·`light` 상수, `copyWith`, `lerp`(Color.lerp). `AppTextStyles` 클래스(생성자에 palette 받아 `AppTypography` 기본 스타일에 `textSecondary` 를 caption 에만 입힘). `extension PaletteContext on BuildContext` — `Theme.of(this).extension<AppPalette>() ?? AppPalette.dark`.
  - `app_colors.dart`: 값을 다크 팔레트로 맞추고 주석에 "화면에서 쓰지 말 것 — context.palette" 명시. (`primary`→민트 `#6FE3D3`, `secondary`→금색 `#F2B85B` 이 아니라 **필드명을 팔레트와 같게**: `background, surface, elevated, separator, textPrimary, textSecondary, accent, onAccent, warning, onWarning, danger`.)
  - `app_typography.dart`: 모든 `color:` 제거, `headline` 17 w600 추가.
  - `app_semantic_colors.dart`: `factory AppSemanticColors.fromPalette(AppPalette p)` (enter=accent, exit=warning, active=accent, inactive=warning, bluetooth=accent), `static final dark/light`.
  - `app_theme.dart`: `static ThemeData _build(AppPalette p, Brightness b)` 로 공통화, `dark()`/`light()` 가 부른다. `ColorScheme.fromSeed` 대신 명시 `ColorScheme(brightness: b, primary: p.accent, onPrimary: p.onAccent, secondary: p.warning, onSecondary: p.onWarning, error: p.danger, onError: Colors.white, surface: p.surface, onSurface: p.textPrimary, onSurfaceVariant: p.textSecondary, outline: p.separator, outlineVariant: p.separator, surfaceContainerHighest: p.elevated)`. `scaffoldBackgroundColor: p.background`, `textTheme` 색은 `apply(bodyColor: p.textPrimary, displayColor: p.textPrimary)`, `appBarTheme.systemOverlayStyle: b == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark`, `inputDecorationTheme(filled: true, fillColor: p.surface, border/enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: AppRadius.small), focusedBorder: accent 1.5)`, `listTileTheme(iconColor: p.textSecondary)`, `segmentedButtonTheme` 생략, `dividerTheme(color: p.separator, thickness: 0.5)`, snackBar/bottomSheet 배경은 `p.elevated`/`p.surface`, `extensions: [p, AppSemanticColors.fromPalette(p)]`.
  - `map_style.dart`: `light` JSON(바탕 `#f2f2f7`, 도로 `#ffffff`, 물 `#c9e4f2`, 공원 `#dcefe4`, 라벨 `#6c6c70`, poi·transit 숨김 — dark 와 같은 키 구조) + `static String forBrightness(Brightness b)`.
- [ ] **Step 4:** 테스트 PASS 확인. 이 시점엔 앱 컴파일이 깨진다(`AppColors.primary` 등 이름 변경) — Task 3 전까지 `flutter analyze` 실패는 정상. **같은 커밋으로 묶지 않고** Task 3 까지 끝낸 뒤 함께 커밋한다.

### Task 2: 화면 모드 설정 상태 · 알림 화면 다크 고정

**Files:**
- Create: `lib/core/theme/app_theme_preference.dart`, `lib/core/theme/app_theme_controller.dart` (+ `.g.dart` 생성)
- Modify: `lib/main.dart`, `lib/app/app.dart:466`, `lib/app/router.dart` (`_AlertRoute` 빌드 결과를 `Theme(data: AppTheme.dark(), child: …)` 로 감쌈)
- Test: `test/core/theme/app_theme_preference_test.dart`, `test/app/alert_route_dark_test.dart`

**Interfaces:**
- Produces: `enum AppThemePreference { system, light, dark }` + `storageValue`, `static AppThemePreference parse(String?)`, `ThemeMode get themeMode`; `class AppThemeStore { read(); write(AppThemePreference) }` key `app.theme_mode`; `appThemeInitialProvider`, `appThemeControllerProvider` (`select(AppThemePreference)`).

- [ ] **Step 1: 실패 테스트**

```dart
test('모르는 값·null 은 system', () {
  expect(AppThemePreference.parse(null), AppThemePreference.system);
  expect(AppThemePreference.parse('purple'), AppThemePreference.system);
  expect(AppThemePreference.parse('light'), AppThemePreference.light);
});
test('themeMode 대응', () {
  expect(AppThemePreference.system.themeMode, ThemeMode.system);
  expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
});
test('저장 후 다시 읽는다', () async {
  SharedPreferences.setMockInitialValues({});
  await const AppThemeStore().write(AppThemePreference.light);
  expect(await const AppThemeStore().read(), AppThemePreference.light);
});
```

알림 화면 테스트: `MaterialApp(theme: AppTheme.light(), home: Theme(data: AppTheme.dark(), child: Builder(...)))` 형태가 아니라, router 에서 쓰는 감싸기 함수 `Widget alertTheme(Widget child)` 를 `lib/app/alert_theme.dart` 로 빼서 그것을 검증한다: 라이트 앱 안에서 `alertTheme(child)` 하위의 `context.palette == AppPalette.dark`.

- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현 — 언어 설정(`app_language_store.dart`, `app_language_controller.dart`)과 같은 모양. 컨트롤러 `select` 는 `Diagnostics.log('settings', 'theme mode changed from=$a to=$b')`, 저장 실패는 `theme mode save failed error=…` 로 삼킨다. `main.dart` 에서 `final themePref = await const AppThemeStore().read();` 후 `appThemeInitialProvider.overrideWithValue(themePref)`. `app.dart`: `theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ref.watch(appThemeControllerProvider).themeMode`.
- [ ] **Step 4:** `dart run build_runner build --delete-conflicting-outputs` 후 테스트 PASS.

### Task 3: 사용처 이전 · 지도 스타일 · 규칙 테스트

**Files:**
- Modify: `AppColors.`·`AppTypography.` 를 쓰는 `lib/features/**`, `lib/core/widgets/**`, `lib/core/map/map_style_guard.dart`, 지도 4곳(`alert_screen.dart:343` 은 dark 고정, `place_map_home_screen.dart:179`, `place_map_picker_screen.dart:342`, `place_form_screen.dart:855` 은 `MapStyle.forBrightness(Theme.of(context).brightness)`)
- Modify: `test/design_system_test.dart` (규칙 추가), 기존 테스트의 `AppColors.` 참조

- [ ] **Step 1: 규칙 테스트 추가** — `design_system_test.dart` 에 `group('색과 글자는 테마에서 읽는다')`: `presentation`·`core/widgets` 파일 소스에서 `RegExp(r'\bAppColors\.')`, `RegExp(r'\bAppTypography\.')` 발견 시 실패, 메시지 "context.palette / context.typo 를 쓴다 — 라이트 모드에서 색이 고정된다(#272)".
- [ ] **Step 2:** FAIL 확인 (위반 목록 출력)
- [ ] **Step 3: 이전** — 대응표: `bgBase→palette.background`, `bgSurface→palette.surface`, `bgElevated→palette.elevated`, `textPrimary/textSecondary→같은 이름`, `primary→palette.accent` (금색이 주색이던 자리 = 주 버튼·강조 → 민트), `secondary→palette.accent`(도착·활성) 단 **출발(exit)·감시 중지 경고 자리는 `palette.warning`** — 의미 색은 `AppSemanticColors` 를 우선 쓴다, `textOnPrimary→palette.onAccent`, `danger→palette.danger`. `AppTypography.x → context.typo.x`. `const` 가 깨지는 곳은 `const` 를 뗀다. `ensureDarkMapStyle` → `ensureMapStyle(controller, where, brightness)` 로 이름·인자 변경, 호출처 갱신.
- [ ] **Step 4:** `flutter analyze` 무경고 + 전체 `flutter test` PASS (기존 테스트의 색 상수 기대값은 팔레트 값으로 갱신).
- [ ] **Step 5: 커밋** (Task 1~3 함께) `… : feat : 라이트·다크 팔레트와 화면 모드 상태를 두고 화면의 색·글자를 테마에서 읽게 바꾼다 …/issues/272`

### Task 4: 설정 화면의 "화면 모드"

**Files:**
- Create: `lib/features/settings/presentation/theme_mode_sheet.dart`
- Modify: `settings_screen.dart` (일반 묶음, 언어 바로 아래), `router.dart` (값·콜백 연결), arb 4개 + gen-l10n
- Test: `test/features/settings/theme_mode_sheet_test.dart`

**Interfaces:** `SettingsScreen({..., required AppThemePreference themePreference, required ValueChanged<AppThemePreference> onThemeChanged})`; `Future<AppThemePreference?> showThemeModeSheet(BuildContext, {required AppThemePreference current})`.

l10n 키: `settingsThemeTitle`(화면 모드 / Appearance / 画面モード / 显示模式), `themeSystem`(기기 설정 따르기 / Match device / 端末の設定に従う / 跟随系统), `themeLight`(라이트 / Light / ライト / 浅色), `themeDark`(다크 / Dark / ダーク / 深色), `themeChanged`(화면 모드를 바꿨어요 / Appearance changed / 画面モードを変更しました / 已更改显示模式). 되돌리기는 기존 `languageUndo` 재사용 대신 `themeUndo`(되돌리기 / Undo / 元に戻す / 撤销).

- [ ] **Step 1: 실패 테스트** — 시트에서 '라이트' 탭 → 반환값 `AppThemePreference.light`; 설정 화면에 '화면 모드' 줄과 현재 값('기기 설정 따르기') 표시.
- [ ] **Step 2:** FAIL
- [ ] **Step 3:** 구현 — `language_sheet.dart` 와 같은 `RadioGroup` 구조, 아이콘 `Icons.contrast_outlined`. 선택 후 스낵바 + 되돌리기(언어와 동일 패턴).
- [ ] **Step 4:** PASS → 커밋 `… : feat : 설정에서 화면 모드(기기·라이트·다크)를 고르게 한다 …`

### Task 5: 공용 컴포넌트 + 장소 폼 · 설정 적용

**Files:**
- Create: `lib/core/widgets/grouped_section.dart`, `lib/core/widgets/app_segmented_control.dart`
- Modify: `place_form_screen.dart` (`_DirectionSelector` 삭제 → `AppSegmentedControl`, 칸들을 `GroupedSection` 으로), `settings_screen.dart` (`_SectionLabel`+`ListTile` 나열 → `GroupedSection`)
- Test: `test/core/widgets/grouped_section_test.dart`, `test/core/widgets/app_segmented_control_test.dart`

**Interfaces:**
- `GroupedSection({String? header, String? footer, required List<Widget> children})` — 자식 사이에 `Divider(indent: 56)`, 카드 `palette.surface` 반경 `AppRadius.small`(16).
- `AppSegmentedControl<T>({required List<AppSegment<T>> segments, required T selected, required ValueChanged<T> onChanged})`, `class AppSegment<T> { final T value; final IconData icon; final String label; }`.

- [ ] **Step 1: 실패 테스트** — 세그먼트: 탭하면 `onChanged(value)`, 선택 칸에 `Semantics(selected: true)`; 그룹: 자식 3개면 구분선 2개, header 문자열 표시.
- [ ] **Step 2:** FAIL
- [ ] **Step 3:** 구현 — 세그먼트 트랙 `palette.elevated` 반경 pill, 선택 칸 `palette.surface`(라이트에선 흰색이라 떠 보임), 선택 글자 `textPrimary` w600, 비선택 `textSecondary`, `AnimatedContainer 180ms`, 높이 44, 아이콘 `AppIconSize.inline`. 폼 아이콘 `where_to_vote_outlined / near_me_outlined / sync_alt_outlined`.
- [ ] **Step 4:** 전체 테스트 PASS (폼·설정 기존 테스트의 finder 가 바뀐 구조에서도 통과하는지) → 커밋 `… : feat : 그룹 목록·세그먼트 컴포넌트를 만들어 장소 폼과 설정에 적용한다 …`

### Task 6: 나머지 화면 정리 · 라이트/다크 눈 확인

**Files:** `lib/features/*/presentation/*.dart` 전체(홈 시트·카드, 위치 선택, 온보딩, 진단, 알림음·진동 시트, 업데이트 시트, 알림 해제 후 화면)

- [ ] **Step 1:** iOS 시뮬레이터에서 라이트·다크 각각 주요 화면 캡처(`/pro-launch`, 요소로 조작). 대비·잘림·고정색 흔적 목록화.
- [ ] **Step 2:** 목록마다 수정 — 묶음은 `GroupedSection`, 카드 배경 `surface`, 선은 `separator`. 하드코딩 흰/검정(`Colors.white`, `Colors.black`)은 팔레트로.
- [ ] **Step 3:** `flutter analyze` + 전체 테스트 PASS, 재캡처로 확인 → 커밋 `… : feat : 나머지 화면을 새 디자인 시스템에 맞춘다 …`

### Task 7: 문서 · README

**Files:** `docs/06-UX.md`(디자인 시스템 절), `docs/10-DECISIONS.md`(새 결정: 라이트 모드, 주색 민트, 알림 화면 다크 고정), `README.md`(기능 목록·스크린샷 문구에 라이트/다크·워치 안내), `CLAUDE.md`(현재 상태 한 단락)

- [ ] **Step 1:** 각 문서 갱신. 06-UX 색 표는 spec 표로 교체, "하지 않는 것"에 `AppColors.` 직접 사용 추가.
- [ ] **Step 2:** 커밋 `… : docs : 라이트 모드와 새 디자인 규칙을 문서에 반영한다 …`

### Task 8: 검증 · 배포

- [ ] `flutter analyze && flutter test` 전체 통과 출력 확인.
- [ ] `/pro-changelog-deploy` — 릴리스 노트 승인 후 deploy PR. Android(Play)·iOS(TestFlight) 워크플로우 둘 다 성공 확인.
- [ ] `/pro-report` 로 #272 보고서, 라벨 `작업완료`, 이슈 닫기.
