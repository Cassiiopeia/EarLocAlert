import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_controller_provider.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 크기 시트의 레이아웃 (이슈 #153)
///
/// **`100%` 가 두 줄로 쪼개졌다.** 슬라이더 옆 `SizedBox(width: 44)` 안에
/// 넣었는데 Pretendard 16px 로 `100%` 가 41px 이라 여유가 3px 뿐이었고,
/// 시스템 글자 크기를 한 단계만 키우면 넘쳤다. 값이 가장 클 때 깨지는 것이
/// 특히 나쁘다 — 100% 는 기본값에 가까워 많은 사용자가 보는 상태다.
///
/// 고정 폭을 늘리는 것은 같은 문제를 뒤로 미루는 것이라, 값을 제목 줄로
/// 옮겨 **넘칠 자리 자체를 없앴다.** 이 테스트가 그것을 지킨다.
class _FullVolumeStore implements AlertVolumeStore {
  @override
  Future<double> volume() async => 1;

  @override
  Future<void> save(double volume) async {}
}

class _Silent implements AlertSoundService {
  @override
  Future<bool> isHeadphoneConnected() async => true;

  @override
  Future<void> play({required double volume, AlertSoundSource? source}) async {}

  @override
  Future<void> stop() async {}
}

class _NoopSystemVolume implements SystemVolumeService {
  @override
  Future<void> raiseTo(double fraction) async {}

  @override
  Future<void> restore() async {}
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Future<void> open(WidgetTester tester, {required double textScale}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertVolumeStoreProvider.overrideWithValue(_FullVolumeStore()),
          alertSoundServiceProvider.overrideWithValue(_Silent()),
          systemVolumeServiceProvider.overrideWithValue(_NoopSystemVolume()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAlertVolumeSheet(context),
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

  testWidgets('100% 가 한 줄로 보인다', (tester) async {
    await open(tester, textScale: 1);

    final text = tester.widget<Text>(find.text('100%'));
    expect(text.maxLines, 1, reason: '두 줄이 되면 시트 높이까지 흔들린다');
  });

  testWidgets('글자 크기를 키워도 깨지지 않는다', (tester) async {
    // 시스템 글자 크기 한두 단계는 흔하다. 예전 고정 폭 44px 은 1.08 배에서
    // 이미 넘쳤다.
    await open(tester, textScale: 1.3);

    expect(find.text('100%'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '넘침 예외가 나면 레이아웃이 글자 크기를 못 견딘 것이다',
    );
  });

  testWidgets('미리듣기는 주 버튼이 아니다', (tester) async {
    await open(tester, textScale: 1);

    expect(
      find.byType(FilledButton),
      findsNothing,
      reason: '즉시 적용 시트에는 확정할 것이 없다 — 하단 주 버튼을 두지 않는다',
    );
    expect(find.widgetWithText(OutlinedButton, '미리듣기'), findsOneWidget);
  });
}
