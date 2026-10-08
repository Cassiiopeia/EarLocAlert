import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/features/alert/data/vibration_service_impl.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_intensity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 진동 경로 선택 (이슈 #235)
///
/// v1.26.2 실기기: 화면 없이 세션이 돌았는데 앱을 열 때까지 한 번도 떨지
/// 않았다. Core Haptics(플러그인)는 백그라운드에서 재생되지 않는다. 이 파일은
/// 백그라운드에서는 시스템 진동을, 전면에서는 햅틱을 쓰는지와 해제 뒤에 떨지
/// 않는지를 지킨다.
void main() {
  late _RecordingLogger logger;
  late _FakeSystemVibration system;
  late List<(int, int?)> plugin;
  late int cancels;

  setUp(() {
    Diagnostics.resetForTest();
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    system = _FakeSystemVibration();
    plugin = [];
    cancels = 0;
  });

  tearDown(Diagnostics.resetForTest);

  VibrationServiceImpl service({
    bool withSystem = true,
    bool hasVibrator = true,
    bool amplitude = true,
  }) => VibrationServiceImpl(
    system: withSystem ? system : null,
    hasVibrator: () async => hasVibrator,
    hasAmplitudeControl: () async => amplitude,
    vibrate: (ms, amp) async => plugin.add((ms, amp)),
    cancel: () async => cancels++,
  );

  const interval = Duration(milliseconds: 20);

  test('백그라운드면 시스템 진동으로 떤다', () async {
    system.background = true;
    final vibration = service();

    await vibration.startRepeating(interval: interval);

    expect(system.pulses, 1);
    expect(plugin, isEmpty);
    expect(logger.lines, contains('[alert] vibration route=system from=none'));
    await vibration.stop();
  });

  test('전면이면 세기가 반영되는 햅틱으로 떤다', () async {
    final vibration = service();

    await vibration.startRepeating(
      interval: interval,
      intensity: VibrationIntensity.strong,
    );

    expect(system.pulses, 0);
    expect(plugin, [
      (VibrationIntensity.strong.pulseMs, VibrationIntensity.strong.amplitude),
    ]);
    expect(logger.lines, contains('[alert] vibration route=haptics from=none'));
    await vibration.stop();
  });

  test('세션 중에 앱을 열면 다음 진동부터 햅틱으로 넘어간다', () async {
    system.background = true;
    final vibration = service();

    await vibration.startRepeating(interval: interval);
    expect(system.pulses, 1);

    system.background = false;
    await Future<void>.delayed(interval * 3);

    expect(plugin, isNotEmpty);
    expect(system.pulses, 1);
    expect(
      logger.lines,
      contains('[alert] vibration route=haptics from=system'),
    );
    // 바뀔 때만 남긴다 — 진동마다 남기면 로그가 묻힌다
    expect(logger.lines.where((l) => l.contains('vibration route=')).length, 2);
    await vibration.stop();
  });

  test('해제하면 타이머가 멈춰 더 떨지 않는다', () async {
    system.background = true;
    final vibration = service();

    await vibration.startRepeating(interval: interval);
    await vibration.stop();
    final after = system.pulses;
    await Future<void>.delayed(interval * 4);

    expect(system.pulses, after);
    expect(cancels, greaterThanOrEqualTo(1));
  });

  test('플러그인이 진동기 없음이라고 해도 백그라운드면 시스템 진동으로 떤다', () async {
    system.background = true;
    final vibration = service(hasVibrator: false);

    await vibration.startRepeating(interval: interval);

    expect(system.pulses, 1);
    await vibration.stop();
  });

  test('시스템 진동 실패는 한 번만 남기고 진동을 이어간다', () async {
    system
      ..background = true
      ..fail = true;
    final vibration = service();

    await vibration.startRepeating(interval: interval);
    await Future<void>.delayed(interval * 3);

    expect(system.attempts, greaterThan(1));
    expect(
      logger.lines.where((l) => l.contains('system vibration failed')).length,
      1,
    );
    await vibration.stop();
  });

  test('시스템 진동이 없는 플랫폼(Android)은 늘 플러그인으로 떤다', () async {
    final vibration = service(withSystem: false, amplitude: false);

    await vibration.startRepeating(interval: interval);

    // 진폭 제어가 없으면 길이만 넘긴다 (이슈 #103)
    expect(plugin, [(VibrationIntensity.normal.pulseMs, null)]);
    await vibration.stop();
  });
}

class _FakeSystemVibration implements SystemVibration {
  bool background = false;
  bool fail = false;
  int pulses = 0;
  int attempts = 0;

  @override
  bool shouldUse() => background;

  @override
  Future<void> pulse() async {
    attempts++;
    if (fail) throw StateError('boom');
    pulses++;
  }
}

class _RecordingLogger implements DiagnosticLogger {
  final List<String> lines = [];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}
