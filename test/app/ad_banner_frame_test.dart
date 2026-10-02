import 'package:ear_loc_alert/app/ad_banner_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 배너 틀 (이슈 #186)
///
/// 실제 광고 SDK 는 플랫폼 뷰라 단위 테스트에서 돌릴 수 없다. 슬롯을 가짜로
/// 끼워, **틀이 지켜야 하는 배치 규칙**만 고정한다.
void main() {
  late ValueChanged<bool> report;

  Widget app({double keyboard = 0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        padding: const EdgeInsets.only(bottom: 34),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AdBannerFrame(
          slotBuilder: (onLoadedChanged) {
            report = onLoadedChanged;
            return const SizedBox(key: Key('slot'), height: 50);
          },
          child: Builder(
            builder: (context) => Text(
              'bottom=${MediaQuery.paddingOf(context).bottom}',
              key: const Key('child'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('로드되기 전에는 화면이 안전 영역을 그대로 받는다', (tester) async {
    await tester.pumpWidget(app());

    // 배너가 없는데 여백을 빼면 화면이 제스처 바에 가린다
    expect(find.text('bottom=34.0'), findsOneWidget);
  });

  testWidgets('로드되면 화면은 아래 안전 영역을 빼고 배너가 맡는다', (tester) async {
    await tester.pumpWidget(app());

    report(true);
    await tester.pump();

    expect(find.text('bottom=0.0'), findsOneWidget);
  });

  testWidgets('배너는 화면 아래에 놓여 화면과 겹치지 않는다', (tester) async {
    await tester.pumpWidget(app());
    report(true);
    await tester.pump();

    final child = tester.getRect(find.byKey(const Key('child')));
    final slot = tester.getRect(find.byKey(const Key('slot')));
    expect(slot.top, greaterThanOrEqualTo(child.bottom));
    // 배너가 화면 맨 아래에 붙는다
    expect(
      slot.bottom,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
  });

  testWidgets('키보드가 올라오면 배너를 숨기고 안전 영역을 돌려준다', (tester) async {
    await tester.pumpWidget(app());
    report(true);
    await tester.pump();

    await tester.pumpWidget(app(keyboard: 300));

    expect(find.byKey(const Key('slot')), findsNothing);
    expect(find.text('bottom=34.0'), findsOneWidget);
  });

  testWidgets('로드 실패로 알리면 다시 안전 영역을 돌려준다', (tester) async {
    await tester.pumpWidget(app());
    report(true);
    await tester.pump();

    report(false);
    await tester.pump();

    expect(find.text('bottom=34.0'), findsOneWidget);
  });
}
