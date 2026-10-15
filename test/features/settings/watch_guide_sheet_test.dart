import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/features/settings/presentation/watch_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 워치 알림 안내 시트 (이슈 #270)
///
/// 한국어는 낱말 사이에 보이지 않는 줄바꿈 금지 문자가 들어가므로 그것을 걷어내고 찾는다
Finder _text(String part) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('\u2060', '').contains(part),
);

Widget _sheet(WatchGuidePlatform platform) {
  return MaterialApp(
    // 문구를 한국어로 찾으므로 언어를 고정한다
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: WatchGuideSheet(platform: platform)),
  );
}

void main() {
  testWidgets('Android 는 Galaxy Wearable 경로를 안내한다', (tester) async {
    await tester.pumpWidget(_sheet(WatchGuidePlatform.android));

    expect(_text('Galaxy Wearable'), findsOneWidget);
    expect(_text('앱 알림'), findsOneWidget);
    expect(_text('Watch 앱'), findsNothing);
  });

  testWidgets('iOS 는 Watch 앱 경로를 안내한다', (tester) async {
    await tester.pumpWidget(_sheet(WatchGuidePlatform.ios));

    expect(_text('Watch 앱'), findsOneWidget);
    expect(_text('Galaxy Wearable'), findsNothing);
  });

  testWidgets('앱 이름이 안내 문구에 들어간다', (tester) async {
    await tester.pumpWidget(_sheet(WatchGuidePlatform.android));

    expect(_text('이어폰위치알림'), findsOneWidget);
  });

  testWidgets('확인을 누르면 시트가 닫힌다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showWatchGuideSheet(
                context,
                platform: WatchGuidePlatform.android,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('알겠어요'), findsOneWidget);

    await tester.tap(find.text('알겠어요'));
    await tester.pumpAndSettle();
    expect(find.text('알겠어요'), findsNothing);
  });
}
