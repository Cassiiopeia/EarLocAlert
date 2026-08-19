import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vibration_intensity.dart';

/// [VibrationIntensityStore] 의 SharedPreferences 구현 (이슈 #103)
///
/// 도메인 데이터가 아니라 단순 설정값이라 SharedPreferences 를 쓴다
/// (docs/02-ARCHITECTURE.md 저장소 표 — 알림음 크기와 같은 이유).
class PrefsVibrationIntensityStore implements VibrationIntensityStore {
  static const _key = 'alert_vibration.intensity';

  @override
  Future<VibrationIntensity> intensity() async {
    final prefs = await SharedPreferences.getInstance();
    // 이름으로 저장한다 — 순서 인덱스로 두면 enum 에 값을 끼워 넣는 순간
    // 기존 사용자의 설정이 조용히 다른 값으로 바뀐다
    return VibrationIntensity.fromName(prefs.getString(_key));
  }

  @override
  Future<void> save(VibrationIntensity intensity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, intensity.name);
  }
}
