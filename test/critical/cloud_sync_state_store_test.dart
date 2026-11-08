import 'package:ear_loc_alert/features/places/data/prefs_cloud_sync_state_store.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 동기화 장부 저장 (#330): 앱을 다시 켜도 장부가 남아야 지운 장소를 삭제로 알린다
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ledger round trip keeps entries', () async {
    const store = PrefsCloudSyncStateStore();
    final entries = [
      SyncLedgerEntry(
        syncId: 'a',
        signature: '{"name":"Home"}',
        updatedAt: DateTime.utc(2026, 11, 5, 10),
      ),
      SyncLedgerEntry(
        syncId: 'b',
        signature: '',
        updatedAt: DateTime.utc(2026, 11, 4),
        isDeleted: true,
      ),
    ];

    await store.saveLedger(entries);
    final read = await store.ledger();

    expect(read.map((entry) => entry.syncId), ['a', 'b']);
    expect(read.first.signature, '{"name":"Home"}');
    expect(read.first.updatedAt, DateTime.utc(2026, 11, 5, 10));
    expect(read.last.isDeleted, isTrue);
  });

  test('broken ledger reads as empty', () async {
    SharedPreferences.setMockInitialValues({'cloud_sync_ledger': '{broken'});
    const store = PrefsCloudSyncStateStore();

    expect(await store.ledger(), isEmpty);
  });

  test('clear removes account and first read mark', () async {
    const store = PrefsCloudSyncStateStore();
    await store.saveAccountEmail('user@gmail.com');
    await store.markFirstReadDone();
    await store.saveLastSyncedAt(DateTime.utc(2026, 11, 5));

    await store.clear();

    expect(await store.accountEmail(), isNull);
    expect(await store.hasCompletedFirstRead(), isFalse);
    expect(await store.lastSyncedAtUtc(), isNull);
  });
}
