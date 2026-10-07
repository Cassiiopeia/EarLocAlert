import 'package:ear_loc_alert/app/ad_banner_frame.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 토스트가 실제로 화면 안, 배너 위에 그려지는가 (이슈 #229)
///
/// 의미 트리에 문구가 있는 것만으로는 부족하다 — QA 에서 "문구는 트리에 있는데
/// 화면에 안 보인다"는 보고가 있었다. 그래서 **그려진 위치**를 잰다.
void main() {
  late ValueChanged<bool> report;

  Widget app({required bool withBanner}) {
    final screen = Scaffold(
      appBar: AppBar(title: const Text('screen')),
      body: Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => context.showToast('first'),
              child: const Text('first'),
            ),
            TextButton(
              onPressed: () => context.showToast('second'),
              child: const Text('second'),
            ),
          ],
        ),
      ),
    );
    return MaterialApp(
      theme: AppTheme.dark(),
      home: withBanner
          ? AdBannerFrame(
              slotBuilder: (onLoadedChanged) {
                report = onLoadedChanged;
                return const SizedBox(key: Key('slot'), height: 60);
              },
              child: screen,
            )
          : screen,
    );
  }

  Rect toastRect(WidgetTester tester) => tester.getRect(find.byType(SnackBar));

  testWidgets('배너가 있으면 토스트는 배너 위, 화면 안에 그려진다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(withBanner: true));
    report(true);
    await tester.pump();

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();

    final toast = toastRect(tester);
    final slot = tester.getRect(find.byKey(const Key('slot')));
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text('first')),
      findsOneWidget,
    );
    // 배너와 겹치면 네이티브 광고 뷰가 토스트를 덮는다
    expect(toast.bottom, lessThanOrEqualTo(slot.top));
    expect(toast.top, greaterThanOrEqualTo(0));
    expect(toast.height, greaterThan(0));
  });

  testWidgets('배너가 없어도 토스트는 화면 안에 그려진다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(withBanner: false));

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();

    final toast = toastRect(tester);
    expect(toast.bottom, lessThanOrEqualTo(844));
    expect(toast.top, greaterThanOrEqualTo(0));
  });

  testWidgets('연달아 띄우면 새 문구가 줄 서지 않고 바로 보인다', (tester) async {
    await tester.pumpWidget(app(withBanner: false));

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second'));
    // 앞 토스트의 4초를 기다리지 않는다 — 퇴장·등장 애니메이션만큼만 흘린다
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text('second')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text('first')),
      findsNothing,
    );
  });
}
