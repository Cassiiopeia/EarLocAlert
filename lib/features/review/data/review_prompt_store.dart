import 'package:shared_preferences/shared_preferences.dart';

/// 후기 창 판단 기록 (SharedPreferences): 알림 해제 횟수, 첫 사용 시각, 마지막 요청 시각
class ReviewPromptStore {
  const ReviewPromptStore();

  // prefs: 알림을 정상적으로 끈 누적 횟수
  static const String _dismissCountKey = 'review_alert_dismiss_count';

  // prefs: 첫 사용 시각 (UTC epoch 밀리초) — 처음 읽을 때 기록
  static const String _firstUsedAtKey = 'review_first_used_at_ms';

  // prefs: 마지막으로 후기 창을 요청한 시각 (UTC epoch 밀리초)
  static const String _lastRequestedAtKey = 'review_last_requested_at_ms';

  Future<int> incrementDismissCount() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_dismissCountKey) ?? 0) + 1;
    await prefs.setInt(_dismissCountKey, next);
    return next;
  }

  Future<int> readDismissCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dismissCountKey) ?? 0;
  }

  /// 첫 사용 시각. 없으면 지금을 기록하고 돌려줌
  Future<DateTime> readOrInitFirstUsedAt(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_firstUsedAtKey);
    if (stored != null) {
      return DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true);
    }
    await prefs.setInt(_firstUsedAtKey, now.millisecondsSinceEpoch);
    return now;
  }

  Future<DateTime?> readLastRequestedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_lastRequestedAtKey);
    return stored == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true);
  }

  Future<void> writeLastRequestedAt(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRequestedAtKey, at.millisecondsSinceEpoch);
  }
}
