import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/l10n/app_language.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/features/settings/presentation/settings_screen.dart';

/// 설정 화면의 잠금화면 알람 줄 (이슈 #235)
Widget _screen(SettingsLockScreenAlarm? alarm) {
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
      appVersion: '1.0.0',
      onOpenTerms: () {},
      onOpenPrivacy: () {},
      lockScreenAlarm: alarm,
    ),
  );
}

/// 한국어 설명은 줄바꿈 방지 문자(U+2060)가 끼어 있다 — 걷어 내고 비교한다
Finder _textContaining(String needle) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ?? '').replaceAll('\u2060', '').contains(needle),
);

void main() {
  testWidgets('Android(값 없음)에는 줄이 없다', (tester) async {
    await tester.pumpWidget(_screen(null));

    expect(find.text('잠금화면 알람'), findsNothing);
  });

  testWidgets('iOS 26 미만이면 버튼 없이 안내만 보인다', (tester) async {
    await tester.pumpWidget(
      _screen(
        const SettingsLockScreenAlarm(state: LockScreenAlarmState.needsNewerOs),
      ),
    );

    expect(find.text('잠금화면 알람'), findsOneWidget);
    expect(_textContaining('iOS 26 이상'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '허용'), findsNothing);
  });

  testWidgets('아직 묻지 않았으면 허용 버튼이 콜백을 부른다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _screen(
        SettingsLockScreenAlarm(
          state: LockScreenAlarmState.notDetermined,
          onAction: () => taps++,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, '허용'));

    expect(taps, 1);
  });

  testWidgets('거부됐으면 설정 열기 버튼을 보인다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _screen(
        SettingsLockScreenAlarm(
          state: LockScreenAlarmState.denied,
          onAction: () => taps++,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, '설정 열기'));

    expect(taps, 1);
  });

  testWidgets('허용됐으면 켜짐 설명만 보이고 버튼은 없다', (tester) async {
    await tester.pumpWidget(
      _screen(const SettingsLockScreenAlarm(state: LockScreenAlarmState.on)),
    );

    expect(_textContaining('잠금 화면 전체에 알람을 띄워요'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
