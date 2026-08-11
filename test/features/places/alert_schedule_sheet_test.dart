import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/presentation/alert_schedule_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시간 창 편집 바텀시트 (이슈 #81)
///
/// **실제 앱 테마로 띄운다.** 이 시트의 버튼이 화면 밖으로 밀려나 사라진
/// 적이 있는데, 원인이 테마의 `filledButtonTheme.minimumSize` 였다. 기본
/// [ThemeData] 로 감싸 테스트하면 그 조합이 재현되지 않아 버그를 놓친다.
Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

/// 시트를 띄우고 결과를 받아오는 진입점.
Future<AlertSchedule?> openSheet(
  WidgetTester tester, {
  AlertSchedule? initial,
}) async {
  AlertSchedule? result;
  await tester.pumpWidget(
    wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showAlertScheduleSheet(context, initial: initial);
          },
          child: const Text('열기'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('AlertScheduleSheet', () {
    testWidgets('추가 버튼이 화면 안에 그려진다 — 회귀 가드', (tester) async {
      await openSheet(tester);

      // 존재만으로는 부족하다. 버튼이 무한 너비가 되어 화면 밖으로
      // 밀려나도 findsOneWidget 은 통과한다 — 실제로 그렇게 놓쳤다.
      final button = find.widgetWithText(FilledButton, '추가');
      expect(button, findsOneWidget);

      final rect = tester.getRect(button);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        rect.right,
        lessThanOrEqualTo(screen.width),
        reason: '추가 버튼이 화면 오른쪽 밖으로 나갔다',
      );
      expect(rect.left, greaterThanOrEqualTo(0));
    });

    testWidgets('추가를 누르면 설정한 창이 돌아온다', (tester) async {
      await openSheet(tester);

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      // 기본값은 평일 08:00~10:00 이다.
      // 반환값은 openSheet 의 result 로 들어가지만, 여기서는 시트가
      // 닫혔는지로 확인한다 — 닫히지 않으면 버튼이 죽어 있었다는 뜻이다.
      expect(find.text('시간대 추가'), findsNothing);
    });

    testWidgets('취소는 아무것도 돌려주지 않는다', (tester) async {
      await openSheet(tester);

      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();

      expect(find.text('시간대 추가'), findsNothing);
    });

    testWidgets('시작과 종료가 같으면 추가할 수 없다', (tester) async {
      await openSheet(
        tester,
        initial: const AlertSchedule(
          daysOfWeek: {DateTime.monday},
          startMinuteOfDay: 8 * 60,
          endMinuteOfDay: 8 * 60,
        ),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '저장'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
