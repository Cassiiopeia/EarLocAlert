import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_intensity.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_controller_provider.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_volume_sheet.dart';
import 'package:ear_loc_alert/features/alert/presentation/vibration_intensity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시트를 닫으면 미리듣기·미리보기가 멎는가 (이슈 #122)
///
/// **`dispose()` 안에서 `ref.read` 를 부르면 터진다.** riverpod 은
/// unmount 시 ref 를 먼저 무효화하고 그다음 `State.dispose()` 를 부르므로,
/// 그 줄에서 예외가 나면 **정지 호출이 아예 실행되지 않는다.**
/// 화면 없이 소리·진동이 남는 것이 정확히 막으려던 상태다.
///
/// 이 테스트가 없어서 지금까지 드러나지 않았다.
class FakeSound implements AlertSoundService {
  int stopCount = 0;

  @override
  Future<bool> isHeadphoneConnected() async => true;

  @override
  Future<void> play({required double volume, AlertSoundSource? source}) async {}

  @override
  Future<void> stop() async => stopCount++;
}

class FakeVibration implements VibrationService {
  int stopCount = 0;

  @override
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  }) async {}

  @override
  Future<void> stop() async => stopCount++;
}

class FakeVolumeStore implements AlertVolumeStore {
  @override
  Future<double> volume() async => 0.8;

  @override
  Future<void> save(double volume) async {}
}

class FakeIntensityStore implements VibrationIntensityStore {
  @override
  Future<VibrationIntensity> intensity() async => VibrationIntensity.normal;

  @override
  Future<void> save(VibrationIntensity intensity) async {}
}

class FakeSystemVolume implements SystemVolumeService {
  @override
  Future<void> raiseTo(double fraction) async {}

  @override
  Future<void> restore() async {}
}

void main() {
  /// 기본 테스트 뷰포트(800x600)는 세로가 짧아 시트가 넘친다.
  /// 실제 휴대전화 비율로 맞춘다 — 여기서 보려는 것은 레이아웃이 아니라
  /// dispose 동작이다.
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

  /// 시트를 열고 배리어를 눌러 닫는다 — 사용자가 실제로 닫는 경로다.
  Future<void> openAndClose(
    WidgetTester tester, {
    required List<Override> overrides,
    required Future<void> Function(BuildContext context) open,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => open(context),
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

    // 시트 밖(배리어)을 눌러 닫는다
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  testWidgets('알림음 크기 시트를 닫으면 미리듣기가 멎는다', (tester) async {
    final sound = FakeSound();

    await openAndClose(
      tester,
      overrides: [
        alertSoundServiceProvider.overrideWithValue(sound),
        alertVolumeStoreProvider.overrideWithValue(FakeVolumeStore()),
        systemVolumeServiceProvider.overrideWithValue(FakeSystemVolume()),
      ],
      open: showAlertVolumeSheet,
    );

    expect(
      sound.stopCount,
      greaterThan(0),
      reason:
          '미리듣기는 반복 재생이라, 멎지 않으면 화면 없이 소리가 계속 난다 — '
          '이 앱에서 가장 피해야 하는 상태다',
    );
  });

  testWidgets('진동 세기 시트를 닫으면 미리보기 진동이 멎는다', (tester) async {
    final vibration = FakeVibration();

    await openAndClose(
      tester,
      overrides: [
        vibrationServiceProvider.overrideWithValue(vibration),
        vibrationIntensityStoreProvider.overrideWithValue(FakeIntensityStore()),
      ],
      open: showVibrationIntensitySheet,
    );

    expect(vibration.stopCount, greaterThan(0));
  });
}
