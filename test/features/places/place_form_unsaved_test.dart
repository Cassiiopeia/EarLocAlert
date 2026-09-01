import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 편집 중 이탈 경고 (이슈 #112)
///
/// **수정한 내용이 조용히 사라지는 것이 이 화면에서 가장 비싼 실수다.**
/// 사용자는 저장된 줄 알고 나가고, 다시 열어봐야 사라진 것을 안다.
/// #97 로 뒤로가기가 정상 동작하게 된 뒤로 더 쉽게 발생한다.
void main() {
  final existing = AlertPlace(
    id: 'p1',
    name: '회사',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 100,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026),
  );

  /// **폼을 push 한 상태로 띄운다.**
  ///
  /// `home:` 으로 바로 띄우면 스택에 route 가 하나뿐이라 `maybePop` 이
  /// 아무 일도 하지 않고, `PopScope` 콜백도 불리지 않는다 — 실제 앱에서는
  /// 홈에서 push 해 들어오므로 그 상황을 그대로 만든다.
  Future<void> pumpPushed(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => form)),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  /// 시스템 뒤로가기를 흉내낸다
  Future<void> pressBack(WidgetTester tester) async {
    final state = tester.state<NavigatorState>(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();
  }

  testWidgets('바꾼 것이 없으면 확인 없이 나간다', (tester) async {
    await pumpPushed(tester, PlaceFormScreen(existing: existing));

    await pressBack(tester);

    // 안 바꿨는데 묻는 것은 방해다
    expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
  });

  testWidgets('이름을 바꾸고 나가려 하면 확인을 받는다 (이슈 #112)', (tester) async {
    await pumpPushed(tester, PlaceFormScreen(existing: existing));

    await tester.enterText(find.byType(TextField).first, '집');
    await tester.pumpAndSettle();

    await pressBack(tester);

    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    expect(find.text('계속 편집'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
  });

  testWidgets('계속 편집을 고르면 화면에 남는다', (tester) async {
    await pumpPushed(tester, PlaceFormScreen(existing: existing));

    await tester.enterText(find.byType(TextField).first, '집');
    await tester.pumpAndSettle();
    await pressBack(tester);

    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();

    // 폼이 살아 있고 입력도 그대로여야 한다
    expect(find.byType(PlaceFormScreen), findsOneWidget);
    expect(find.text('집'), findsOneWidget);
  });

  testWidgets('신규 등록에서 빈 폼은 확인 없이 나간다', (tester) async {
    await pumpPushed(tester, const PlaceFormScreen());

    await pressBack(tester);

    // 버릴 것이 없다
    expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
  });

  group('알림음 변경 (이슈 #121)', () {
    /// 시트 대신 값을 바로 돌려주는 가짜 선택기.
    /// 폼은 `sounds` 를 모르므로 이 콜백이 유일한 연결점이다.
    Future<AlertSound?> pickCustom(AlertSound current) async =>
        const CustomSoundRef('u-1');

    testWidgets('알림음을 바꾸고 나가려 하면 확인을 받는다', (tester) async {
      await pumpPushed(
        tester,
        PlaceFormScreen(existing: existing, onPickSound: pickCustom),
      );

      // 폼이 길어 알림음 항목이 화면 밖에 있다 — ListView 는 lazy 라
      // 스크롤해서 만들어야 찾을 수 있다
      await tester.dragUntilVisible(
        find.text('알림음'),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('알림음'));
      await tester.pumpAndSettle();

      await pressBack(tester);

      expect(
        find.text('저장하지 않고 나갈까요?'),
        findsOneWidget,
        reason: '알림음만 바꾸고 나가면 그것도 조용히 사라진다',
      );
    });

    testWidgets('알림음 항목은 콜백이 없으면 나오지 않는다', (tester) async {
      await pumpPushed(tester, PlaceFormScreen(existing: existing));

      expect(
        find.text('알림음'),
        findsNothing,
        reason:
            '배선되지 않은 화면에서 눌러도 아무 일이 없는 항목을 '
            '보여주면 고장으로 보인다',
      );
    });

    testWidgets('기본음 그대로면 신규 폼은 확인 없이 나간다', (tester) async {
      await pumpPushed(tester, PlaceFormScreen(onPickSound: pickCustom));

      await pressBack(tester);

      expect(
        find.text('저장하지 않고 나갈까요?'),
        findsNothing,
        reason: '빈 폼을 열었다 닫는 것은 버릴 것이 없다',
      );
    });
  });

  testWidgets('신규 등록에서 입력했으면 확인을 받는다', (tester) async {
    await pumpPushed(tester, const PlaceFormScreen());

    await tester.enterText(find.byType(TextField).first, '새 장소');
    await tester.pumpAndSettle();

    await pressBack(tester);

    // 이름과 위치까지 넣어놓고 실수로 나가면 처음부터 다시 해야 한다
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
  });
}
