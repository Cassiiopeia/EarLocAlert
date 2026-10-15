import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/core/widgets/grouped_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS 설정 앱식 묶음 (이슈 #272)
void main() {
  testWidgets('머리글을 보이고 행 사이에만 구분선을 둔다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GroupedSection(
            header: '알림',
            children: [Text('a'), Text('b'), Text('c')],
          ),
        ),
      ),
    );
    expect(find.text('알림'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('자식이 하나면 구분선이 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: GroupedSection(children: [Text('a')])),
      ),
    );
    expect(find.byType(Divider), findsNothing);
  });
}
