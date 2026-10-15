import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/components/grouped_list_row.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 묶음 목록 안의 한 줄 (#276)
Widget _host(Widget row) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: row),
);

void main() {
  testWidgets('navigation — 누르면 콜백, 오른쪽 화살표', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GroupedListRow.navigation(
          icon: Icons.language_outlined,
          title: '언어',
          subtitle: '기기 설정 따르기',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('언어'));
    expect(taps, 1);
    expect(find.byIcon(Icons.chevron_right_outlined), findsOneWidget);
  });

  testWidgets('toggle — 줄 어디를 눌러도 스위치가 바뀐다', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      _host(
        GroupedListRow.toggle(
          title: '이어폰 소리 알림',
          value: false,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    await tester.tap(find.text('이어폰 소리 알림'));
    expect(changed, isTrue);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('value — 오른쪽에 값을 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        GroupedListRow.value(
          icon: Icons.info_outlined,
          title: '앱 버전',
          valueText: '1.34.0',
          onTap: null,
        ),
      ),
    );
    expect(find.text('1.34.0'), findsOneWidget);
  });

  testWidgets('enabled false — 눌러도 반응하지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GroupedListRow.navigation(
          title: '알림음',
          onTap: () => taps++,
          enabled: false,
        ),
      ),
    );
    await tester.tap(find.text('알림음'));
    expect(taps, 0);
  });

  testWidgets('문장 제목은 한국어 낱말 중간에서 줄이 끊기지 않게 한다 (#276 회귀)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // 줄바꿈 처리는 한국어에서만 켜진다 — 언어를 확정하려면 위임자가 필요하다
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: GroupedListRow.toggle(
            title: '이어폰이 연결된 경우에만 소리가 납니다',
            keepTitleWordsTogether: true,
            value: true,
            onChanged: null,
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('이')),
    );
    expect(title.data, contains('\u2060'));
  });
}
