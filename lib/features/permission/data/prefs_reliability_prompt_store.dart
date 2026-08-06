import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reliability_prompt_store.dart';

/// SharedPreferences 기반 [ReliabilityPromptStore] 구현 (이슈 #74)
class PrefsReliabilityPromptStore implements ReliabilityPromptStore {
  const PrefsReliabilityPromptStore();

  static const _key = 'permission.reliability_prompt_seen';

  @override
  Future<bool> wasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } on Object {
      // 읽기 실패는 "아직 안 권했다"로 본다 — 한 번 더 권하는 쪽이
      // 알림을 놓치는 쪽보다 낫다
      return false;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } on Object {
      // 저장 실패는 다음 실행에서 한 번 더 묻는 것으로 끝난다
    }
  }

  @override
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object {
      // 되돌리기 실패는 온보딩이 곧장 done 으로 넘어가는 것으로 끝난다
    }
  }
}
