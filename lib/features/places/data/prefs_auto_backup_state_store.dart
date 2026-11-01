import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auto_backup.dart';

/// [AutoBackupStateStore] SharedPreferences 구현 (#314)
class PrefsAutoBackupStateStore implements AutoBackupStateStore {
  const PrefsAutoBackupStateStore();

  // prefs: 마지막 자동 백업 시각 (UTC ISO-8601)
  static const _lastAtKey = 'auto_backup.last_at';
  // prefs: 마지막으로 쓴 장소 내용 서명 (PlaceBackup JSON, 시각 고정)
  static const _signatureKey = 'auto_backup.last_signature';

  @override
  Future<DateTime?> lastBackupAtUtc() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<String?> lastSignature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_signatureKey);
  }

  @override
  Future<void> saveWritten({
    required DateTime atUtc,
    required String signature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAtKey, atUtc.toUtc().toIso8601String());
    await prefs.setString(_signatureKey, signature);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAtKey);
    await prefs.remove(_signatureKey);
  }
}
