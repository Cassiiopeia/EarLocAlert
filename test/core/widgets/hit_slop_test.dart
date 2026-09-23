import 'package:ear_loc_alert/core/widgets/hit_slop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 보이는 모양보다 넓은 탭 범위 (이슈 #155 QA)
void main() {
  Future<({List<String> taps, Rect button})> pump(WidgetTester tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HitSlop(
            onTap: () => taps.add('slop'),
            padding: const EdgeInsets.all(8),
            child: FloatingActionButton(
              onPressed: () => taps.add('button'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              child: const Icon(Icons.add_outlined),
            ),
          ),
        ),
      ),
    );
    return (
      taps: taps,
      button: tester.getRect(find.byType(FloatingActionButton)),
    );
  }

  testWidgets('테두리 바깥 여백을 눌러도 동작한다', (tester) async {
    final (:taps, :button) = await pump(tester);

    // FAB 테두리에서 5dp 바깥 — 예전에는 반응이 없던 자리
    await tester.tapAt(Offset(button.left - 5, button.center.dy));
    await tester.tapAt(Offset(button.center.dx, button.bottom + 5));

    expect(taps, ['slop', 'slop']);
  });

  testWidgets('버튼 위를 누르면 버튼만 한 번 — 두 번 불리지 않는다', (tester) async {
    final (:taps, :button) = await pump(tester);

    await tester.tapAt(button.center);
    await tester.pump();

    expect(taps, ['button'], reason: '장소 등록이 두 번 열리면 안 된다');
  });

  testWidgets('여백 밖은 받지 않는다', (tester) async {
    final (:taps, :button) = await pump(tester);

    await tester.tapAt(Offset(button.left - 12, button.center.dy));

    expect(taps, isEmpty);
  });
}
