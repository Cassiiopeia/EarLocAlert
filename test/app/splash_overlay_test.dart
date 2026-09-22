import 'package:ear_loc_alert/app/splash_overlay.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_session.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_controller_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스플래시 전환 애니메이션 (이슈 #150)
///
/// **이 화면의 안전선은 "알림을 늦추지 않는 것"이다.** 잔잔하게 보이려고
/// 넣은 것이 급할 때 알림 화면을 0.7초 미루면 넣지 않느니만 못하다.
/// 건너뛰는 두 경로를 여기서 지킨다.
class _FakeActiveAlert extends ActiveAlert {
  _FakeActiveAlert(this._initial);

  final AlertSession? _initial;

  @override
  AlertSession? build() => _initial;
}

void main() {
  AlertSession session() => AlertSession(
    placeId: 'p1',
    placeName: '소만사 출근',
    direction: AlertDirection.enter,
    startedAt: DateTime.utc(2026, 9, 22, 9, 16),
    audioRoute: AudioRoute.silent,
  );

  setUp(() {
    // 기본은 "핀이 준비된" 상태다. 준비 전 경로는 따로 켜서 확인한다.
    SplashOverlay.isWarm = true;
  });
  tearDown(() => SplashOverlay.isWarm = false);

  Future<void> pump(WidgetTester tester, {AlertSession? active}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAlertProvider.overrideWith(() => _FakeActiveAlert(active)),
        ],
        child: const MaterialApp(home: SplashOverlay(child: Text('홈'))),
      ),
    );
  }

  testWidgets('처음에는 커튼이 화면을 덮는다', (tester) async {
    await pump(tester);

    // 아직 걷히지 않았으므로 스플래시 그림이 트리에 있다
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('시간이 지나면 걷히고 트리에서 빠진다', (tester) async {
    await pump(tester);

    await tester.pumpAndSettle(const Duration(milliseconds: 900));

    expect(
      find.byType(Image),
      findsNothing,
      reason: '투명하게만 두면 그 자리의 탭을 계속 먹는다',
    );
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets('알림이 이미 서 있으면 아예 그리지 않는다', (tester) async {
    await pump(tester, active: session());

    // 한 프레임도 기다리지 않는다 — 알림 화면이 가려지면 안 된다
    expect(find.byType(Image), findsNothing, reason: '앱이 죽었다 살아난 경로 (이슈 #130)');
  });

  testWidgets('핀 디코드 전이면 아예 그리지 않는다', (tester) async {
    // 핀 없는 검은 판이 번쩍이느니 애니메이션을 버린다
    SplashOverlay.isWarm = false;

    await pump(tester);

    expect(find.byType(Image), findsNothing);
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets('커튼은 탭을 가로막지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAlertProvider.overrideWith(() => _FakeActiveAlert(null)),
        ],
        child: MaterialApp(
          home: SplashOverlay(
            child: Center(
              child: GestureDetector(
                onTap: () => taps++,
                child: const Text('눌러'),
              ),
            ),
          ),
        ),
      ),
    );

    // 커튼이 아직 덮고 있는 동안 누른다
    await tester.tap(find.text('눌러'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 1, reason: 'IgnorePointer 가 빠지면 첫 탭이 먹힌다');
  });
}
