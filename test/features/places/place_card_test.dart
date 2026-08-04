import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/theme/app_semantic_colors.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_card.dart';
import 'package:flutter/material.dart';
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

Widget wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [AppSemanticColors.dark]),
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

    testWidgets('길게 누르면 삭제 — 실수로 닿기 어려운 동작에 둔다', (tester) async {
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
      expect(deleted, isTrue);
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
