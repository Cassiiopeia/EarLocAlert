import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vibration_waveform.dart';

/// [VibrationPatternStore] 의 SharedPreferences 구현 (#311)
class PrefsVibrationPatternStore implements VibrationPatternStore {
  // prefs: 기본 진동 패턴 이름 (VibrationPattern.name)
  static const _key = 'alert_vibration.pattern';

  @override
  Future<VibrationPattern> pattern() async {
    final prefs = await SharedPreferences.getInstance();
    return VibrationPattern.fromName(prefs.getString(_key));
  }

  @override
  Future<void> save(VibrationPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pattern.name);
  }
}
