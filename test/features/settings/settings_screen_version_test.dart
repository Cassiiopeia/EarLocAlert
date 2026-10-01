import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/l10n/app_language.dart';
import 'package:ear_loc_alert/features/settings/presentation/settings_screen.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';

/// 설정 화면의 앱 버전 줄 (이슈 #179)
Widget _screen({required String version, required VoidCallback onCheck}) {
  return MaterialApp(
    // 문구를 한국어로 찾으므로 언어를 고정한다 (이슈 #163)
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(
      onOpenVolumeSettings: () {},
      onOpenVibrationSettings: () {},
      onOpenDiagnostics: () {},
      language: AppLanguage.ko,
      onLanguageChanged: (_) {},
      appVersion: version,
      onCheckUpdate: onCheck,
    ),
  );
}

void main() {
  testWidgets('앱 버전이 목록 맨 끝에 보인다', (tester) async {
    await tester.pumpWidget(_screen(version: '1.20.3 (113)', onCheck: () {}));
    await tester.scrollUntilVisible(find.text('앱 버전'), 300);

    expect(find.text('앱 버전'), findsOneWidget);
    expect(find.text('1.20.3 (113)'), findsOneWidget);
  });

  testWidgets('읽지 못했으면 대시로 자리를 지킨다', (tester) async {
    await tester.pumpWidget(_screen(version: '-', onCheck: () {}));
    await tester.scrollUntilVisible(find.text('앱 버전'), 300);

    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('업데이트 확인을 누르면 콜백이 불린다', (tester) async {
    var checks = 0;
    await tester.pumpWidget(
      _screen(version: '1.20.3 (113)', onCheck: () => checks++),
    );
    await tester.scrollUntilVisible(find.text('업데이트 확인'), 300);
    await tester.tap(find.text('업데이트 확인'));

    expect(checks, 1);
  });
}
