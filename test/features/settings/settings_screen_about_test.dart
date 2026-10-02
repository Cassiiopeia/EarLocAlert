import 'package:ear_loc_alert/core/l10n/app_language.dart';
import 'package:ear_loc_alert/core/l10n/generated/app_localizations.dart';
import 'package:ear_loc_alert/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 설정의 정보 섹션 (이슈 #188)
///
/// 약관·방침은 스토어 심사 항목이다. 항목이 조용히 빠지면 심사에서 반려된다.
void main() {
  Widget app({
    VoidCallback? onTerms,
    VoidCallback? onPrivacy,
    VoidCallback? onAdPrivacy,
  }) {
    return MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(
        onOpenVolumeSettings: () {},
        onOpenVibrationSettings: () {},
        onOpenDiagnostics: () {},
        language: AppLanguage.system,
        onLanguageChanged: (_) {},
        onOpenTerms: onTerms ?? () {},
        onOpenPrivacy: onPrivacy ?? () {},
        onOpenAdPrivacy: onAdPrivacy,
      ),
    );
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  testWidgets('이용약관과 개인정보처리방침 항목이 있고 누르면 열린다', (tester) async {
    var terms = 0;
    var privacy = 0;
    await tester.pumpWidget(
      app(onTerms: () => terms++, onPrivacy: () => privacy++),
    );
    await scrollToEnd(tester);

    await tester.tap(find.text('이용약관'));
    await tester.tap(find.text('개인정보처리방침'));

    expect(terms, 1);
    expect(privacy, 1);
  });

  testWidgets('광고 동의를 다시 열 지역이 아니면 그 항목을 숨긴다', (tester) async {
    await tester.pumpWidget(app());
    await scrollToEnd(tester);

    expect(find.text('광고 개인정보 설정'), findsNothing);
  });

  testWidgets('광고 동의를 다시 열 지역이면 항목이 보이고 누르면 열린다', (tester) async {
    var opened = 0;
    await tester.pumpWidget(app(onAdPrivacy: () => opened++));
    await scrollToEnd(tester);

    await tester.tap(find.text('광고 개인정보 설정'));

    expect(opened, 1);
  });

  testWidgets('오픈소스 라이선스 항목이 있다', (tester) async {
    await tester.pumpWidget(app());
    await scrollToEnd(tester);

    expect(find.text('오픈소스 라이선스'), findsOneWidget);
  });
}
