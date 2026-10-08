import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/features/alert/data/prefs_vibration_check_store.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_check.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_intensity.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_controller_provider.dart';
import 'package:ear_loc_alert/features/alert/presentation/vibration_check_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements DiagnosticLogger {
  final lines = <String>[];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}

class _FakeVibration implements VibrationService {
  final calls = <String>[];

  @override
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  }) async => calls.add('start:${intensity.name}');

  @override
  Future<void> stop() async => calls.add('stop');
}

class _FixedIntensityStore implements VibrationIntensityStore {
  @override
  Future<VibrationIntensity> intensity() async => VibrationIntensity.weak;

  @override
  Future<void> save(VibrationIntensity intensity) async {}
}

/// 진동 시험 (이슈 #237)
///
/// iOS 는 진동 설정을 앱에 알려주지 않는다. 사용자의 답이 유일한 단서라
/// **답이 남아야** 홈 경고가 다음 시험까지 유지된다.
void main() {
  late _RecordingLogger logger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
  });
  tearDown(Diagnostics.resetForTest);

  group('저장소', () {
    test('시험한 적이 없으면 null 이다', () async {
      expect(await PrefsVibrationCheckStore().last(), isNull);
    });

    test('답과 시각이 그대로 돌아온다 — 시각은 UTC 다', () async {
      final store = PrefsVibrationCheckStore();
      final at = DateTime.utc(2026, 10, 8, 9, 30);
      await store.save(VibrationCheckResult(felt: false, answeredAt: at));

      final loaded = await store.last();
      expect(loaded?.felt, isFalse);
      expect(loaded?.answeredAt, at);
      expect(loaded?.answeredAt.isUtc, isTrue);
    });

    test('나중 답이 앞의 답을 덮는다 — "예"로 다시 답하면 경고가 풀린다', () async {
      final store = PrefsVibrationCheckStore();
      await store.save(
        VibrationCheckResult(felt: false, answeredAt: DateTime.utc(2026)),
      );
      await store.save(
        VibrationCheckResult(felt: true, answeredAt: DateTime.utc(2026, 2)),
      );
      expect((await store.last())?.felt, isTrue);
    });
  });

  group('시험 흐름', () {
    ProviderContainer makeContainer(_FakeVibration vibration) {
      final container = ProviderContainer(
        overrides: [
          vibrationServiceProvider.overrideWithValue(vibration),
          vibrationIntensityStoreProvider.overrideWithValue(
            _FixedIntensityStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('알림과 같은 진동 서비스로 저장된 세기로 한 번 떨고 멈춘다', () async {
      final vibration = _FakeVibration();
      final container = makeContainer(vibration);

      await container
          .read(vibrationCheckProvider.notifier)
          .fire(trigger: 'settings');

      expect(vibration.calls, ['start:weak', 'stop']);
      expect(
        logger.lines,
        contains('[vibration] test fired trigger=settings intensity=weak'),
      );
    });

    test('답하면 저장되고 상태가 바로 바뀐다', () async {
      final container = makeContainer(_FakeVibration());
      expect(await container.read(vibrationCheckProvider.future), isNull);

      await container.read(vibrationCheckProvider.notifier).answer(felt: false);

      expect(container.read(vibrationCheckProvider).valueOrNull?.felt, isFalse);
      expect((await PrefsVibrationCheckStore().last())?.felt, isFalse);
      expect(logger.lines, contains('[vibration] test answered felt=false'));
    });

    test('앱을 다시 켜도 마지막 답을 읽어 온다', () async {
      await PrefsVibrationCheckStore().save(
        VibrationCheckResult(felt: false, answeredAt: DateTime.utc(2026)),
      );
      final container = makeContainer(_FakeVibration());
      expect(
        (await container.read(vibrationCheckProvider.future))?.felt,
        isFalse,
      );
    });
  });
}
