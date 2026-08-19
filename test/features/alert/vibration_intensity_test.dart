import 'package:ear_loc_alert/features/alert/data/prefs_vibration_intensity_store.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_intensity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 진동 세기 설정 (이슈 #103)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VibrationIntensity', () {
    test('세기가 올라가면 진폭도 길이도 함께 올라간다', () {
      // 진폭 제어가 없는 기기에서도 차이가 느껴져야 하므로
      // 두 축이 같은 방향으로 움직여야 한다
      expect(
        VibrationIntensity.weak.amplitude,
        lessThan(VibrationIntensity.normal.amplitude),
      );
      expect(
        VibrationIntensity.normal.amplitude,
        lessThan(VibrationIntensity.strong.amplitude),
      );
      expect(
        VibrationIntensity.weak.pulseMs,
        lessThan(VibrationIntensity.normal.pulseMs),
      );
      expect(
        VibrationIntensity.normal.pulseMs,
        lessThan(VibrationIntensity.strong.pulseMs),
      );
    });

    test('가장 약한 단계도 진폭이 0 이 아니다 — 느껴지지 않으면 알림이 아니다', () {
      for (final intensity in VibrationIntensity.values) {
        expect(intensity.amplitude, greaterThan(0));
        expect(intensity.amplitude, lessThanOrEqualTo(255));
      }
    });

    test('알 수 없는 이름은 보통으로 떨어진다', () {
      expect(VibrationIntensity.fromName('없는값'), VibrationIntensity.normal);
      expect(VibrationIntensity.fromName(null), VibrationIntensity.normal);
    });

    test('저장된 이름은 그대로 복원된다', () {
      for (final intensity in VibrationIntensity.values) {
        expect(VibrationIntensity.fromName(intensity.name), intensity);
      }
    });
  });

  group('PrefsVibrationIntensityStore', () {
    late PrefsVibrationIntensityStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = PrefsVibrationIntensityStore();
    });

    test('저장한 값이 그대로 돌아온다', () async {
      await store.save(VibrationIntensity.strong);
      expect(await store.intensity(), VibrationIntensity.strong);
    });

    test('저장된 값이 없으면 보통이다 — 기존 사용자의 알림이 달라지면 안 된다', () async {
      expect(await store.intensity(), VibrationIntensity.normal);
    });

    test('손상된 값이 있어도 보통으로 돌아온다', () async {
      SharedPreferences.setMockInitialValues({
        'alert_vibration.intensity': '깨진값',
      });
      expect(await store.intensity(), VibrationIntensity.normal);
    });
  });
}
