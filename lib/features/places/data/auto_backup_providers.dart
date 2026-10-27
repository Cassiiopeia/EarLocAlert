import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auto_backup.dart';
import 'auto_backup_folder_channel.dart';
import 'prefs_auto_backup_state_store.dart';

part 'auto_backup_providers.g.dart';

@Riverpod(keepAlive: true)
AutoBackupService autoBackupService(Ref ref) => const AutoBackupService(
  folder: AutoBackupFolderChannel(),
  state: PrefsAutoBackupStateStore(),
);

/// 설정 화면 표시용 (#314): 폴더 이름(null = 꺼짐)과 마지막 자동 백업 시각
@riverpod
Future<({String? folderName, DateTime? lastBackupAtUtc})> autoBackupStatus(
  Ref ref,
) async {
  final service = ref.watch(autoBackupServiceProvider);
  return (
    folderName: await service.folder.name(),
    lastBackupAtUtc: await service.state.lastBackupAtUtc(),
  );
}
