import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/presentation/alert_schedule_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시간 창 편집 바텀시트 (이슈 #81)
///
/// **실제 앱 테마로 띄운다.** 이 시트의 주 버튼이 화면 밖으로 밀려나
/// 사라진 적이 있는데, 원인이 테마의 `filledButtonTheme.minimumSize`
/// (`Size.fromHeight` = 최소 너비 무한대)였다. 기본 [ThemeData] 로 감싸면
/// 그 조합이 재현되지 않아 버그가 통과한다.
Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

/// 시트를 띄우고, 닫힐 때의 반환값을 [results] 에 담는다.
///
/// 반환값은 시트가 닫힌 뒤에야 정해지므로 호출 시점에 돌려받을 수 없다.
/// 목록으로 받아 테스트가 나중에 읽는다.
Future<void> openSheet(
  WidgetTester tester,
  List<AlertSchedule?> results, {
  AlertSchedule? initial,
}) async {
  await tester.pumpWidget(
    wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            results.add(
              await showAlertScheduleSheet(context, initial: initial),
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  group('AlertScheduleSheet', () {
    testWidgets('주 버튼이 화면 안에 그려진다 — 회귀 가드', (tester) async {
      await openSheet(tester, []);

      // 존재 확인만으로는 부족하다. 버튼이 무한 너비가 되어 화면 밖으로
      // 밀려나도 findsOneWidget 은 통과한다 — 실제로 그렇게 놓쳤다.
      final button = find.widgetWithText(FilledButton, '추가');
      expect(button, findsOneWidget);

      final rect = tester.getRect(button);
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(
        rect.right,
        lessThanOrEqualTo(screenWidth),
        reason: '주 버튼이 화면 오른쪽 밖으로 나갔다',
      );
      expect(rect.width, greaterThan(0));
    });

    testWidgets('취소도 화면 안에 있다', (tester) async {
      await openSheet(tester, []);

      final rect = tester.getRect(find.widgetWithText(TextButton, '취소'));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screenWidth));
    });

    testWidgets('추가를 누르면 기본값(평일 08:00~10:00)이 돌아온다', (tester) async {
      final results = <AlertSchedule?>[];
      await openSheet(tester, results);

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final created = results.single;
      expect(created, isNotNull);
      expect(created!.daysOfWeek, {1, 2, 3, 4, 5});
      expect(created.startMinuteOfDay, 8 * 60);
      expect(created.endMinuteOfDay, 10 * 60);
    });

    testWidgets('요일을 바꾸면 그대로 돌아온다', (tester) async {
      final results = <AlertSchedule?>[];
      await openSheet(tester, results);

      await tester.tap(find.widgetWithText(ActionChip, '주말'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(results.single?.daysOfWeek, {DateTime.saturday, DateTime.sunday});
    });

    testWidgets('취소는 null 을 돌려준다 — 창이 더해지지 않는다', (tester) async {
      final results = <AlertSchedule?>[];
      await openSheet(tester, results);

      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.single, isNull);
    });

    testWidgets('편집으로 열면 기존 값이 채워지고 저장으로 나온다', (tester) async {
      final results = <AlertSchedule?>[];
      const existing = AlertSchedule(
        daysOfWeek: {DateTime.friday},
        startMinuteOfDay: 23 * 60,
        endMinuteOfDay: 2 * 60,
      );
      await openSheet(tester, results, initial: existing);

      expect(find.text('시간대 편집'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect(results.single, existing);
    });

    testWidgets('시작과 종료가 같으면 저장할 수 없다', (tester) async {
      await openSheet(
        tester,
        [],
        initial: const AlertSchedule(
          daysOfWeek: {DateTime.monday},
          startMinuteOfDay: 8 * 60,
          endMinuteOfDay: 8 * 60,
        ),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '저장'),
      );
      expect(button.onPressed, isNull, reason: '0분짜리 창은 만들 수 없어야 한다');
    });

    testWidgets('요일을 모두 끄면 저장할 수 없다', (tester) async {
      await openSheet(
        tester,
        [],
        initial: const AlertSchedule(
          daysOfWeek: {DateTime.monday},
          startMinuteOfDay: 8 * 60,
          endMinuteOfDay: 10 * 60,
        ),
      );

      // 유일하게 켜져 있는 '월' 을 끈다 — 영영 열리지 않는 창이 된다.
      await tester.tap(find.widgetWithText(FilterChip, '월'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '저장'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
