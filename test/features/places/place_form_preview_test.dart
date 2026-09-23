import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 폼의 위치 미리보기 (이슈 #155)
///
/// **이슈 본문에 적힌 테스트가 레포에 없었다.** 그 사이 미리보기 탭이
/// 통째로 죽은 채 배포됐다 — 지도와 마스크가 둘 다 `IgnorePointer` 라
/// 바깥 `GestureDetector` 가 hit test 에 아무것도 걸리지 않았다.
void main() {
  final existing = AlertPlace(
    id: 'p1',
    name: '회사',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 200,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026),
  );

  Future<void> pump(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark(), home: form),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('좌표가 없으면 미리보기를 그리지 않는다', (tester) async {
    await pump(tester, const PlaceFormScreen());

    // 지도 키 없이 빌드된 경우에도 폼은 동작해야 한다
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('아직 위치를 고르지 않았습니다'), findsOneWidget);
  });

  testWidgets('미리보기를 탭하면 지도 선택이 열린다', (tester) async {
    var opened = 0;
    await pump(
      tester,
      PlaceFormScreen(
        existing: existing,
        onPickOnMap: (_) async {
          opened++;
          return null;
        },
      ),
    );

    // 가운데·모서리 어디를 눌러도 열려야 한다 — 실기기에서는 네 곳을
    // 눌러 하나도 열리지 않았다
    final map = find.byType(GoogleMap);
    final rect = tester.getRect(map);
    for (final point in [
      rect.center,
      rect.topLeft + const Offset(20, 20),
      rect.bottomRight - const Offset(20, 20),
    ]) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
    }

    expect(opened, 3, reason: '미리보기는 확인만 되고 고칠 수 없는 상태가 된다');
  });

  testWidgets('이름을 쓰다 지도에 다녀와도 키보드가 다시 올라오지 않는다', (tester) async {
    // 에뮬레이터 QA 에서 돌아오자마자 키보드가 올라와 방금 고른 위치의
    // 미리보기를 덮었다 — 떠날 때 포커스를 쥐고 있으면 되돌아온다
    await pump(
      tester,
      PlaceFormScreen(existing: existing, onPickOnMap: (_) async => null),
    );

    await tester.enterText(find.byType(TextField).first, '집');
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('지도에서 다시 선택'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('반경을 바꾸면 원 반지름이 따라간다', (tester) async {
    await pump(tester, PlaceFormScreen(existing: existing));

    double circleRadius() =>
        tester.widget<GoogleMap>(find.byType(GoogleMap)).circles.single.radius;

    expect(circleRadius(), 200);

    // 슬라이더를 끝까지 민다
    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(
      circleRadius(),
      greaterThan(200),
      reason: '슬라이더와 지도가 따로 놀면 미리보기가 거짓말을 한다',
    );
  });
}
