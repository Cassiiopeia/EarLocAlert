import 'package:flutter/services.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/platform/channel_names.dart';
import '../domain/auto_backup.dart';

/// [AutoBackupFolder] 네이티브 채널 구현 (#314): Kotlin·Swift `BackupFolderChannel`
class AutoBackupFolderChannel implements AutoBackupFolder {
  const AutoBackupFolderChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(ChannelNames.backupFolder);

  final MethodChannel _channel;

  @override
  Future<String?> pick() => _call<String>('pickFolder');

  @override
  Future<String?> name() => _call<String>('folderName');

  @override
  Future<bool> write({
    required String fileName,
    required String content,
  }) async =>
      await _call<bool>('write', {'fileName': fileName, 'content': content}) ??
      false;

  @override
  Future<void> clear() => _call<void>('clearFolder');

  /// 채널 실패는 없음으로 (기록만): 백업 실패가 앱을 멈추면 안 됨
  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on Object catch (error) {
      Diagnostics.log(
        'backup',
        'folder channel failed method=$method error=$error',
      );
      return null;
    }
  }
}
