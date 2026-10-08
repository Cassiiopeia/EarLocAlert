import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vibration_check.dart';

/// [VibrationCheckStore] 의 SharedPreferences 구현 (이슈 #237)
///
/// 도메인 데이터가 아니라 사용자의 한 번 답이라 진동 세기와 같은 곳에 둔다.
class PrefsVibrationCheckStore implements VibrationCheckStore {
  static const _keyFelt = 'vibration_check.felt';
  static const _keyAnsweredAt = 'vibration_check.answered_at';

  @override
  Future<VibrationCheckResult?> last() async {
    final prefs = await SharedPreferences.getInstance();
    final felt = prefs.getBool(_keyFelt);
    final at = prefs.getString(_keyAnsweredAt);
    if (felt == null || at == null) return null;
    // 시각이 깨져 있으면 답만 믿는다 — 답이 경고 여부를 정하고 시각은 기록용이다
    final answeredAt =
        DateTime.tryParse(at)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return VibrationCheckResult(felt: felt, answeredAt: answeredAt);
  }

  @override
  Future<void> save(VibrationCheckResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFelt, result.felt);
    await prefs.setString(
      _keyAnsweredAt,
      result.answeredAt.toUtc().toIso8601String(),
    );
  }
}
