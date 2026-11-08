import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/components/coach_mark.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 코치마크 다음 버튼 (#326): 앱 테마의 가로 전체 버튼이 말풍선 Row 안에서 폭 계산을 깨 "다음"이 사라졌다
void main() {
  Future<({GlobalKey first, GlobalKey second})> pumpHome(
    WidgetTester tester,
  ) async {
    final first = GlobalKey();
    final second = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(key: first, width: 120, height: 40),
              const Spacer(),
              SizedBox(key: second, width: 120, height: 40),
            ],
          ),
        ),
      ),
    );
    return (first: first, second: second);
  }

  Future<bool> showTwoSteps(
    WidgetTester tester,
    ({GlobalKey first, GlobalKey second}) keys,
  ) async {
    var isFinished = false;
    final context = tester.element(find.byType(Scaffold));
    showCoachMarks(
      context,
      steps: [
        CoachMarkStep(targetKey: keys.first, title: 'One', description: 'a'),
        CoachMarkStep(targetKey: keys.second, title: 'Two', description: 'b'),
      ],
    ).then((_) => isFinished = true);
    // 링 숨쉬기가 계속 돌아 settle 대신 시간으로 넘김
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return isFinished;
  }

  testWidgets('next button is visible and moves to the next step', (
    tester,
  ) async {
    final keys = await pumpHome(tester);
    await showTwoSteps(tester, keys);

    expect(find.text('Next'), findsOneWidget);
    expect(tester.getSize(find.text('Next')).width, greaterThan(0));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside the bubble moves to the next step', (
    tester,
  ) async {
    final keys = await pumpHome(tester);
    await showTwoSteps(tester, keys);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Two'), findsOneWidget);
  });
}
