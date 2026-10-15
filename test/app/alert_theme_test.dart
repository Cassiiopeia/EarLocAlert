import 'package:ear_loc_alert/app/alert_theme.dart';
import 'package:ear_loc_alert/core/theme/app_palette.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 화면은 라이트 모드에서도 다크다 (이슈 #272)
void main() {
  testWidgets('라이트 앱 안에서도 알림 화면은 다크 팔레트다', (tester) async {
    late AppPalette inside;
    late AppPalette outside;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            outside = context.palette;
            return alertTheme(
              Builder(
                builder: (context) {
                  inside = context.palette;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(outside, AppPalette.light);
    expect(inside, AppPalette.dark);
  });
}
