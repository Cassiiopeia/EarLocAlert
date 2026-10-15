import 'package:ear_loc_alert/core/l10n/app_language.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme_preference.dart';
import 'package:ear_loc_alert/features/settings/presentation/settings_screen.dart';
import 'package:ear_loc_alert/features/settings/presentation/theme_mode_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면 모드 선택 (이슈 #272)
Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('시트에서 라이트를 고르면 그 값이 돌아온다', (tester) async {
    AppThemePreference? picked;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showThemeModeSheet(
                context,
                current: AppThemePreference.system,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('라이트'));
    await tester.pumpAndSettle();

    expect(picked, AppThemePreference.light);
  });

  testWidgets('설정에 화면 모드 줄과 지금 값이 보인다', (tester) async {
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          onOpenVolumeSettings: () {},
          onOpenVibrationSettings: () {},
          onOpenDiagnostics: () {},
          onReportProblem: () {},
          onExportPlaces: () {},
          onImportPlaces: () {},
          language: AppLanguage.ko,
          onLanguageChanged: (_) {},
          themePreference: AppThemePreference.system,
          onThemeChanged: (_) {},
          appVersion: '1.0.0',
          onOpenTerms: () {},
          onOpenPrivacy: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('화면 모드'), 300);

    expect(find.text('화면 모드'), findsOneWidget);
    // 부제는 낱말 사이에 보이지 않는 줄바꿈 금지 문자가 들어간다
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && (w.data ?? '').replaceAll('\u2060', '') == '기기 설정 따르기',
      ),
      findsOneWidget,
    );
  });
}
