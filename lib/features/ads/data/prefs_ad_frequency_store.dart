import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ad_frequency_store.dart';

/// SharedPreferences 기반 [AdFrequencyStore] 구현
///
/// 단일 값들이라 Drift 를 쓰지 않는다 (docs/03-DOMAIN.md 저장소 경계).
class PrefsAdFrequencyStore implements AdFrequencyStore {
  PrefsAdFrequencyStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyLastShown = 'ads.lastShownAtMillis';
  static const _keyShownToday = 'ads.shownToday';
  static const _keyShownDate = 'ads.shownDate';
  static const _keyLaunched = 'ads.launched';

  @override
  Future<AdFrequencyState> read() async {
    final millis = _prefs.getInt(_keyLastShown);
    final lastShownAt = millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

    return AdFrequencyState(
      lastShownAt: lastShownAt,
      shownToday: _shownTodayFor(DateTime.now()),
      isFirstLaunch: !(_prefs.getBool(_keyLaunched) ?? false),
    );
  }

  /// 날짜가 바뀌면 카운터를 0 으로 본다.
  ///
  /// 저장된 값을 지우지 않고 읽을 때 판단한다 — 자정에 앱이 떠 있지 않아도
  /// 정확히 동작한다.
  int _shownTodayFor(DateTime now) {
    final storedDate = _prefs.getString(_keyShownDate);
    if (storedDate != _dateKey(now)) return 0;
    return _prefs.getInt(_keyShownToday) ?? 0;
  }

  @override
  Future<void> recordShown(DateTime now) async {
    final today = _dateKey(now);
    final previous = _shownTodayFor(now);

    await _prefs.setInt(_keyLastShown, now.toUtc().millisecondsSinceEpoch);
    await _prefs.setString(_keyShownDate, today);
    await _prefs.setInt(_keyShownToday, previous + 1);
  }

  @override
  Future<void> markLaunched() async {
    await _prefs.setBool(_keyLaunched, true);
  }

  /// 일자 경계는 **사용자 로컬 기준**이다 — "오늘 몇 번 봤나"는
  /// 사용자가 체감하는 하루를 따라야 한다 (저장 값 자체는 UTC).
  String _dateKey(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month}-${local.day}';
  }
}
