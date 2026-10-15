import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_colors.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

AlertPlace makePlace({
  String id = 'p1',
  AlertDirection direction = AlertDirection.enter,
  bool enabled = true,
}) {
  return AlertPlace(
    id: id,
    name: '회사',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 100,
    direction: direction,
    enabled: enabled,
    createdAt: DateTime.utc(2026),
  );
}

/// **실제 앱 테마로 띄운다.** 손으로 만든 [ThemeData] 로 감싸면 테마가
/// 강제하는 버튼 크기·색이 빠져, 앱에서만 재현되는 레이아웃 문제를 놓친다
/// (시간대 시트의 주 버튼이 화면 밖으로 밀려난 적이 있다).
Widget wrap(Widget child) {
  return MaterialApp(
    // 문구를 한국어로 찾으므로 언어를 한국어로 고정한다 (이슈 #163)
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

/// 장소 카드 — 지도 홈 시트와 목록 양쪽에서 쓰는 공용 조각.
void main() {
  group('PlaceCard', () {
    testWidgets('이름·방향·반경이 표시된다', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );

      expect(find.text('회사'), findsOneWidget);
      expect(find.text('도착 알림 · 반경 100m'), findsOneWidget);
    });

    testWidgets('탭은 편집, 토글은 활성 전환 — 서로 섞이지 않는다 (F1.7)', (tester) async {
      var tapped = false;
      bool? toggled;
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () => tapped = true,
            onToggle: (value) => toggled = value,
            onDelete: () {},
          ),
        ),
      );

      await tester.tap(find.text('회사'));
      expect(tapped, isTrue);
      expect(toggled, isNull);

      await tester.tap(find.byType(Switch));
      expect(toggled, isFalse); // 켜져 있던 것을 껐다
    });

    testWidgets('왼쪽으로 끝까지 밀면 삭제 — 확인 없이 지우고 되돌리기로 복구한다 (#205)', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () => deleted++,
          ),
        ),
      );

      await tester.fling(find.text('회사'), const Offset(-500, 0), 2000);
      await tester.pumpAndSettle();

      expect(deleted, 1);
      // 놓은 즉시 트리에서 빠져야 한다 — 저장소 갱신을 기다리면 Dismissible 이 죽는다
      expect(find.text('회사'), findsNothing);
    });

    testWidgets('지운 자리에 다른 장소가 들어오면 그 카드는 보인다 (#274)', (tester) async {
      // 홈 목록에서 가운데 카드를 지우면 아래 카드가 그 자리로 올라온다.
      // 지운 카드의 "접힘" 상태가 그 자리에 남으면 아래 카드가 빈 칸이 됐다
      Widget card(String id, String name) => wrap(
        PlaceCard(
          place: makePlace(id: id).copyWith(name: name),
          onTap: () {},
          onToggle: (_) {},
          onDelete: () {},
        ),
      );

      await tester.pumpWidget(card('p1', '회사'));
      await tester.fling(find.text('회사'), const Offset(-500, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('회사'), findsNothing);

      await tester.pumpWidget(card('p2', '집'));
      await tester.pumpAndSettle();
      expect(find.text('집'), findsOneWidget);
    });

    testWidgets('조금만 밀고 놓으면 제자리로 돌아온다 — 실수로 지워지지 않는다', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.drag(find.text('회사'), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(deleted, isFalse);
      expect(find.text('회사'), findsOneWidget);
    });

    testWidgets('밀지 않았을 때는 삭제 아이콘이 투명이다 — 모서리 틈에 붉은 기가 없다 (#266)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byIcon(Icons.delete_outlined),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0);
    });

    testWidgets('밀면 삭제 아이콘이 줄의 오른쪽 끝에 머문다 — 카드를 따라가지 않는다 (#266)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );
      final row = tester.getRect(find.byType(PlaceCard));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('회사')),
      );
      // 첫 이동은 터치 슬롭에 쓰이므로 나눠서 민다
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();

      final card = tester.getRect(find.byType(AnimatedContainer).first);
      final icon = tester.getRect(find.byIcon(Icons.delete_outlined));

      // 카드는 밀린 만큼 왼쪽으로 갔다
      expect(card.right, lessThan(row.right - 100));
      // 아이콘은 드러난 영역(카드 오른쪽 끝 ~ 줄 오른쪽 끝) 안에 있다
      expect(icon.left, greaterThan(card.right));
      expect(icon.right, lessThanOrEqualTo(row.right));

      await gesture.up();
      await tester.pumpAndSettle();
      // 놓으면 제자리로 돌아오고 아이콘은 다시 투명이다
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byIcon(Icons.delete_outlined),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0,
      );
    });

    test('삭제 판은 카드 뒤로 이어지고 오른쪽 끝은 줄 끝에 맞는다 (#266)', () {
      const size = Size(300, 80);

      // 밀지 않았으면 그리지 않는다
      expect(deletePanelRect(size, 0), isNull);

      // 40%(확정 거리) 밀었을 때: 카드는 120 만큼 왼쪽에 있다
      final rect = deletePanelRect(size, 0.4)!;
      // 카드 기준 오른쪽 끝 = 폭 + 밀린 만큼 → 줄 기준으로는 줄의 오른쪽 끝
      expect(rect.right, 300 + 120);
      // 왼쪽은 카드 오른쪽 끝(300)보다 반지름만큼 안쪽 — 둥근 모서리 틈이 빈다
      expect(rect.left, 300 - 24);
      expect(rect.top, 0);
      expect(rect.bottom, 80);
    });

    test('밀기 정도는 확정 거리에서 1 이 된다 (#266)', () {
      expect(deleteSwipeIntensity(0), 0);
      expect(deleteSwipeIntensity(0.2), closeTo(0.5, 1e-9));
      expect(deleteSwipeIntensity(0.4), 1);
      expect(deleteSwipeIntensity(0.9), 1);
    });

    testWidgets('오른쪽으로 밀어도 지워지지 않는다 — 한 방향만 쓴다', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.fling(find.text('회사'), const Offset(500, 0), 2000);
      await tester.pumpAndSettle();

      expect(deleted, isFalse);
    });

    testWidgets('길게 눌러도 지워지지 않는다 — 예전 방식은 없앴다 (#205)', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.longPress(find.text('회사'));
      expect(deleted, isFalse);
    });

    testWidgets('스크린리더에는 삭제 동작이 따로 열린다 — 스와이프는 못 하므로', (tester) async {
      var deleted = false;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(PlaceCard));
      final ids = node.getSemanticsData().customSemanticsActionIds;
      expect(ids, isNotNull);
      expect(ids, isNotEmpty);
      expect(CustomSemanticsAction.getAction(ids!.first)!.label, '삭제');

      // 실제 스크린리더와 같은 경로로 실행한다
      tester.semantics.performAction(
        find.semantics.byAction(SemanticsAction.customAction),
        SemanticsAction.customAction,
        args: ids.first,
      );
      await tester.pump();
      expect(deleted, isTrue);
      handle.dispose();
    });

    testWidgets('지도에서 지목되면 테두리가 생긴다 — 활성 여부와 다른 축', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            selected: true,
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PlaceCard),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('활성 카드는 흰색 반전이 아니다 — 한 층 밝은 다크 배경이다 (#88)', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PlaceCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color,
        AppColors.elevated,
        reason: '흰 카드는 다크 화면에서 혼자 뜬다 — 활성은 명도 한 층 위다',
      );
    });

    testWidgets('비활성 카드는 낮은 층으로 가라앉는다', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlaceCard(
            place: makePlace(enabled: false),
            onTap: () {},
            onToggle: (_) {},
            onDelete: () {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PlaceCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.decoration! as BoxDecoration).color, AppColors.surface);
    });

    testWidgets('방향별 문구가 카드에 그대로 나온다', (tester) async {
      for (final (direction, label) in [
        (AlertDirection.enter, '도착 알림'),
        (AlertDirection.exit, '출발 알림'),
        (AlertDirection.both, '도착·출발'),
      ]) {
        await tester.pumpWidget(
          wrap(
            PlaceCard(
              place: makePlace(direction: direction),
              onTap: () {},
              onToggle: (_) {},
              onDelete: () {},
            ),
          ),
        );
        expect(
          find.textContaining(label),
          findsOneWidget,
          reason: '$direction 은 "$label" 로 표시되어야 한다',
        );
      }
    });
  });
}
