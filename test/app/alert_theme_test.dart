import 'package:ear_loc_alert/app/alert_theme.dart';
import 'package:ear_loc_alert/core/theme/app_palette.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 화면은 라이트 모드에서도 다크다 (이슈 #272)
Future<AppPalette> _paletteInside(
  WidgetTester tester,
  Widget Function(Widget probe) wrap,
) async {
  late AppPalette inside;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: wrap(
        Builder(
          builder: (context) {
            inside = context.palette;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return inside;
}

void main() {
  testWidgets('라이트 앱 안에서도 알림 화면은 다크 팔레트다', (tester) async {
    expect(await _paletteInside(tester, alertTheme), AppPalette.dark);
  });

  testWidgets('세션이 빈 자리 화면도 다크다 — 해제 직후 흰 화면이 번쩍이지 않게', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: alertEmptyPlaceholder()),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final context = tester.element(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      AppPalette.dark.background,
    );
  });

  testWidgets('알림 화면 상태바 아이콘은 늘 밝은색이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: alertTheme(const SizedBox())),
    );
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value, SystemUiOverlayStyle.light);
  });
}
