import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/core/ui/components/status_bar_icons_following_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱바 없는 화면의 상태바 아이콘색 (이슈 #272)
Future<SystemUiOverlayStyle> _style(
  WidgetTester tester,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const StatusBarIconsFollowingTheme(child: SizedBox()),
    ),
  );
  return tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      )
      .value;
}

void main() {
  testWidgets('라이트면 어두운 아이콘', (tester) async {
    expect(await _style(tester, AppTheme.light()), SystemUiOverlayStyle.dark);
  });

  testWidgets('다크면 밝은 아이콘', (tester) async {
    expect(await _style(tester, AppTheme.dark()), SystemUiOverlayStyle.light);
  });
}
