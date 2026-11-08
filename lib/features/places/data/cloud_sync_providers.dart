import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/cloud_sync.dart';
import 'google_cloud_sync_account.dart';
import 'google_drive_cloud_sync_remote.dart';
import 'prefs_cloud_sync_state_store.dart';

part 'cloud_sync_providers.g.dart';

@Riverpod(keepAlive: true)
CloudSyncAccount cloudSyncAccount(Ref ref) => GoogleCloudSyncAccount();

@Riverpod(keepAlive: true)
CloudSyncRemote cloudSyncRemote(Ref ref) =>
    GoogleDriveCloudSyncRemote(account: ref.watch(cloudSyncAccountProvider));

@Riverpod(keepAlive: true)
CloudSyncStateStore cloudSyncStateStore(Ref ref) =>
    const PrefsCloudSyncStateStore();

/// 설정 화면 표시용 (#330): 연결 계정(null = 꺼짐)과 마지막 동기화 시각
@riverpod
Future<({String? accountEmail, DateTime? lastSyncedAtUtc})> cloudSyncStatus(
  Ref ref,
) async {
  final store = ref.watch(cloudSyncStateStoreProvider);
  return (
    accountEmail: await store.accountEmail(),
    lastSyncedAtUtc: await store.lastSyncedAtUtc(),
  );
}
