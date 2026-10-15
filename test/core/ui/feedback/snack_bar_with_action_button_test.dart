import 'package:ear_loc_alert/core/ui/feedback/app_feedback.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 버튼 달린 스낵바 (#276)
void main() {
  testWidgets('뒤에 오는 안내가 앞의 되돌리기를 걷지 않을 수 있다 — 줄을 세운다', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    showSnackBarWithActionButton(
      messenger,
      message: '장소를 지웠어요',
      actionLabel: '되돌리기',
      onActionPressed: () {},
    );
    await tester.pump();
    // 앱 업데이트 안내처럼 사용자 동작과 무관하게 뜨는 것은 줄을 선다
    showSnackBarWithActionButton(
      messenger,
      message: '업데이트 준비됨',
      actionLabel: '다시 시작',
      onActionPressed: () {},
      replaceCurrentSnackBar: false,
    );
    await tester.pump();

    expect(find.text('되돌리기'), findsOneWidget);
  });
}
