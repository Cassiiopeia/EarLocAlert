import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_session.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 화면의 지도 카드와 해제 버튼 (이슈 #142)
///
/// **해제 버튼 크기가 이 화면의 안전선이다.** 지도를 넣느라 버튼을
/// 줄였는데, 이 버튼은 버스에서 화면을 보지 않고 엄지로 누르는 용도다.
/// 더 줄이자는 변경이 들어오면 여기서 걸린다.
void main() {
  AlertSession session({double? lat, double? lng, int? radius}) {
    return AlertSession(
      placeId: 'p1',
      placeName: '소만사 출근',
      direction: AlertDirection.enter,
      startedAt: DateTime.utc(2026, 9, 18, 9, 16),
      audioRoute: AudioRoute.silent,
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    AlertSession value, {
    VoidCallback? onDismiss,
  }) async {
    // 이 화면은 세로로 꽉 찬 레이아웃이다. 테스트 기본 뷰포트(800×600)는
    // 실제 폰보다 훨씬 납작해 넘침이 난다 — 실기기 비율로 맞춘다.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AlertScreen(session: value, onDismiss: onDismiss ?? () {}),
      ),
    );
  }

  group('hasMapLocation', () {
    test('셋 다 있어야 지도를 그린다', () {
      expect(
        session(lat: 37.5, lng: 127.0, radius: 200).hasMapLocation,
        isTrue,
      );
    });

    test('하나라도 없으면 그리지 않는다', () {
      expect(session().hasMapLocation, isFalse);
      expect(session(lat: 37.5, lng: 127.0).hasMapLocation, isFalse);
      expect(session(lat: 37.5, radius: 200).hasMapLocation, isFalse);
    });
  });

  group('좌표가 없을 때', () {
    testWidgets('지도 카드를 그리지 않는다', (tester) async {
      await pump(tester, session());

      // 반경 칩은 카드 안에만 있다 — 카드가 없으면 이것도 없다
      expect(find.textContaining('반경'), findsNothing);
    });

    testWidgets('해제 버튼이 원래 크기로 돌아간다', (tester) async {
      await pump(tester, session());

      final box = tester.getSize(find.byType(FilledButton));
      expect(
        box.height,
        greaterThanOrEqualTo(200),
        reason: '카드가 빠진 자리를 버튼이 가져가야 한다',
      );
    });

    testWidgets('장소명과 시각은 그대로 보인다', (tester) async {
      await pump(tester, session());

      expect(find.text('소만사 출근'), findsOneWidget);
      expect(find.text('도착했습니다'), findsOneWidget);
      // 지도가 없다고 알림 자체가 망가지면 안 된다
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('해제 버튼', () {
    testWidgets('보이는 것보다 넓은 범위에서 눌린다', (tester) async {
      var dismissed = 0;
      await pump(tester, session(), onDismiss: () => dismissed++);

      // 버튼 바로 아래 여백 — 눈에는 버튼이 아니지만 눌려야 한다
      final rect = tester.getRect(find.byType(FilledButton));
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 8));
      await tester.pump();

      expect(
        dismissed,
        1,
        reason: '급할 때 살짝 빗나가도 꺼져야 한다 (이슈 #142)',
      );
    });
  });
}
