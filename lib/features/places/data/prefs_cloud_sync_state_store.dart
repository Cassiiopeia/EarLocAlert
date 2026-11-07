import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/cloud_sync.dart';
import '../domain/cloud_sync_merge.dart';

/// [CloudSyncStateStore] SharedPreferences 구현 (#330)
class PrefsCloudSyncStateStore implements CloudSyncStateStore {
  const PrefsCloudSyncStateStore();

  // prefs: 변경 장부 JSON 배열 [{id, sig, at, del}]
  static const _ledgerKey = 'cloud_sync_ledger';
  // prefs: 연결한 구글 계정 이메일
  static const _accountKey = 'cloud_sync_account_email';
  // prefs: 마지막 동기화 시각 (UTC ISO-8601)
  static const _lastSyncedKey = 'cloud_sync_last_synced_at';
  // prefs: 연결 뒤 첫 읽기 완료 (true 전엔 올리지 않음)
  static const _firstReadKey = 'cloud_sync_first_read_done';

  @override
  Future<List<SyncLedgerEntry>> ledger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ledgerKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final ledgerJson in list.cast<Map<String, Object?>>())
          SyncLedgerEntry(
            syncId: ledgerJson['id']! as String,
            signature: ledgerJson['sig']! as String,
            updatedAt: DateTime.parse(ledgerJson['at']! as String).toUtc(),
            isDeleted: ledgerJson['del'] == true,
          ),
      ];
    } on Object catch (error) {
      // 깨진 장부는 빈 장부로 > 다음 동기화가 현재 장소로 다시 만듦 (삭제 표시만 잃음)
      Diagnostics.log('cloudsync', 'ledger read failed error=$error');
      return const [];
    }
  }

  @override
  Future<void> saveLedger(List<SyncLedgerEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ledgerKey,
      jsonEncode([
        for (final entry in entries)
          {
            'id': entry.syncId,
            'sig': entry.signature,
            'at': entry.updatedAt.toUtc().toIso8601String(),
            'del': entry.isDeleted,
          },
      ]),
    );
  }

  @override
  Future<String?> accountEmail() async =>
      (await SharedPreferences.getInstance()).getString(_accountKey);

  @override
  Future<void> saveAccountEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, email);
    }
  }

  @override
  Future<DateTime?> lastSyncedAtUtc() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _lastSyncedKey,
    );
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> saveLastSyncedAt(DateTime atUtc) async =>
      (await SharedPreferences.getInstance()).setString(
        _lastSyncedKey,
        atUtc.toUtc().toIso8601String(),
      );

  @override
  Future<bool> hasCompletedFirstRead() async =>
      (await SharedPreferences.getInstance()).getBool(_firstReadKey) ?? false;

  @override
  Future<void> markFirstReadDone() async =>
      (await SharedPreferences.getInstance()).setBool(_firstReadKey, true);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _ledgerKey,
      _accountKey,
      _lastSyncedKey,
      _firstReadKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
