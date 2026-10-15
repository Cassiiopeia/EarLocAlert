import 'package:ear_loc_alert/core/theme/app_palette.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/core/theme/map_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 라이트·다크 팔레트와 테마 (이슈 #272)
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, p) in [
    ('dark', AppPalette.dark),
    ('light', AppPalette.light),
  ]) {
    test('$name 본문 대비 4.5:1 이상', () {
      expect(_contrast(p.textPrimary, p.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
    });

    // 주색·금색은 글자(감시 중·경고 배너)로도 쓰인다 — 본문 기준을 맞춘다 (#272 QA)
    test('$name 주색·금색 글자 대비 4.5:1 이상', () {
      expect(_contrast(p.accent, p.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.accent, p.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.warning, p.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.warning, p.background), greaterThanOrEqualTo(4.5));
    });

    test('$name 삭제 글자 대비 4.5:1 이상', () {
      expect(_contrast(p.danger, p.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.danger, p.surface), greaterThanOrEqualTo(4.5));
    });

    test('$name 주 버튼 글자 대비 3:1 이상', () {
      expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(3));
      expect(_contrast(p.onWarning, p.warning), greaterThanOrEqualTo(3));
    });
  }

  test('테마마다 맞는 팔레트가 실린다', () {
    expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  testWidgets('context.typo.caption 은 보조색이다', (tester) async {
    late TextStyle caption;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            caption = context.typo.caption;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(caption.color, AppPalette.light.textSecondary);
  });

  test('선택된 칩 글자는 본문색이다 — 흰 글자가 연한 바탕에 묻히지 않게', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final p = theme.extension<AppPalette>()!;
      expect(theme.colorScheme.onSecondaryContainer, p.textPrimary);
      expect(theme.chipTheme.checkmarkColor, p.textPrimary);
    }
  });

  test('밝기별 지도 스타일', () {
    expect(MapStyle.forBrightness(Brightness.dark), MapStyle.dark);
    expect(MapStyle.forBrightness(Brightness.light), MapStyle.light);
  });
}
