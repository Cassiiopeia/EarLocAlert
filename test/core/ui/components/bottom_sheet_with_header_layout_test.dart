import 'package:ear_loc_alert/core/ui/components/bottom_sheet_with_header_layout.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 공통 바텀시트 틀 (#276)
Widget _host(void Function(BuildContext) open, {double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => open(context),
            child: const Text('열기'),
          ),
        ),
      ),
    );

Widget _layout({List<Widget> body = const [Text('본문')]}) =>
    BottomSheetWithHeaderLayout(
      headerIcon: Icons.watch_outlined,
      title: '워치로 알림 받기',
      description: '워치 쪽 설정을 한 번만 켜 주세요.',
      body: Column(mainAxisSize: MainAxisSize.min, children: body),
      primaryAction: FilledButton(onPressed: () {}, child: const Text('확인')),
    );

void main() {
  testWidgets('머리(아이콘·제목·설명)와 본문, 주 버튼을 그린다', (tester) async {
    await tester.pumpWidget(
      _host((c) => showAppBottomSheet<void>(c, builder: (_) => _layout())),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.watch_outlined), findsOneWidget);
    expect(find.text('워치로 알림 받기'), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('글자를 두 배로 키우고 본문이 길어도 넘치지 않는다 — 스크롤된다', (tester) async {
    await tester.pumpWidget(
      _host(
        (c) => showAppBottomSheet<void>(
          c,
          builder: (_) =>
              _layout(body: [for (var i = 0; i < 30; i++) Text('긴 안내 문장 $i')]),
        ),
        textScale: 2,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('키보드가 올라오면 시트 아래 여백이 키보드 높이만큼 늘어난다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(body: _layout()),
        ),
      ),
    );
    final button = tester.getBottomLeft(find.text('확인'));
    expect(button.dy, lessThanOrEqualTo(800 - 300));
  });
}
