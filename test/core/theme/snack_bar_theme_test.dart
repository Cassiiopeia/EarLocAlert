import 'package:ear_loc_alert/core/theme/app_colors.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스낵바는 앱 팔레트를 따른다 (이슈 #205)
///
/// 테마가 없으면 다크 스킴이 밝은 막대로 칠해, 어두운 화면 아래에 흰 막대가
/// 혼자 뜬다. 삭제 직후 "되돌리기" 안내가 가장 자주 마주치는 자리다.
void main() {
  test('스낵바는 한 층 위 배경이고 액션은 주색이다', () {
    final theme = AppTheme.dark().snackBarTheme;

    expect(theme.backgroundColor, AppColors.bgElevated);
    expect(theme.actionTextColor, AppColors.primary);
    expect(theme.behavior, SnackBarBehavior.floating);
  });

  testWidgets('띄운 스낵바가 실제로 어두운 배경이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('안내'),
                  action: SnackBarAction(label: '되돌리기', onPressed: () {}),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.bgElevated);
  });
}
