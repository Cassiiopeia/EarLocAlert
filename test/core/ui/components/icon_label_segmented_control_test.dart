import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/core/ui/components/icon_label_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS 결 세그먼트 선택 (이슈 #272)
Widget _control(int selected, ValueChanged<int> onChanged) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: IconLabelSegmentedControl<int>(
      selected: selected,
      onChanged: onChanged,
      segments: const [
        IconLabelSegment(
          value: 0,
          icon: Icons.where_to_vote_outlined,
          label: '도착',
        ),
        IconLabelSegment(value: 1, icon: Icons.near_me_outlined, label: '출발'),
        IconLabelSegment(value: 2, icon: Icons.sync_alt_outlined, label: '둘 다'),
      ],
    ),
  ),
);

void main() {
  testWidgets('칸을 누르면 그 값으로 바뀐다', (tester) async {
    int? changed;
    await tester.pumpWidget(_control(0, (v) => changed = v));
    await tester.tap(find.text('출발'));
    expect(changed, 1);
  });

  testWidgets('선택된 칸만 선택 상태로 읽힌다', (tester) async {
    await tester.pumpWidget(_control(2, (_) {}));
    final selected = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected == true)
        .toList();
    expect(selected, hasLength(1));
    expect(
      find.descendant(
        of: find.byWidget(selected.single),
        matching: find.text('둘 다'),
      ),
      findsOneWidget,
    );
  });
}
