import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alert_effects.dart';

/// [AlertVolumeStore] 의 SharedPreferences 구현 (이슈 #86)
///
/// 도메인 데이터가 아니라 단순 설정값이라 SharedPreferences 를 쓴다
/// (docs/02-ARCHITECTURE.md 저장소 표 — 광고 빈도 저장소와 같은 이유).
class PrefsAlertVolumeStore implements AlertVolumeStore {
  static const _key = 'alert_volume.level';

  @override
  Future<double> volume() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key);
    if (stored == null) return AlertVolumeStore.defaultVolume;
    // 손상된 값이 소리를 죽이거나 귀를 때리면 안 된다
    return stored.clamp(0.0, 1.0);
  }

  @override
  Future<void> save(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, volume.clamp(0.0, 1.0));
  }
}
