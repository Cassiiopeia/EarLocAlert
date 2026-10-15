import 'package:shared_preferences/shared_preferences.dart';

/// 워치 안내를 이미 보여줬는지 (이슈 #270)
///
/// 첫 장소 등록 직후 한 번만 띄운다. 설정 화면에서는 언제든 다시 열 수 있어
/// 이 기록은 자동 안내에만 쓴다.
class PrefsWatchGuideStore {
  const PrefsWatchGuideStore();

  static const _key = 'settings.watch_guide_seen';

  Future<bool> wasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } on Object {
      // 읽기 실패는 "안 봤다"로 본다 — 한 번 더 보여주는 쪽이 안내를 놓치는 쪽보다 낫다
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } on Object {
      // 저장 실패는 다음 등록 때 한 번 더 보이는 것으로 끝난다
    }
  }
}
