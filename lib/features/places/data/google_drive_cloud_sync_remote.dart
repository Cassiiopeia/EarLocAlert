import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/cloud_sync.dart';
import '../domain/cloud_sync_document.dart';

/// [CloudSyncRemote] Drive v3 구현 (#330): appDataFolder 의 `earlocalert-sync.json` 한 개
///
/// 모든 실패는 던지지 않고 결과로 (읽기 실패 > [CloudSyncReadFailed], 쓰기 실패 > false)
class GoogleDriveCloudSyncRemote implements CloudSyncRemote {
  GoogleDriveCloudSyncRemote({required CloudSyncAccount account})
    : _account = account;

  final CloudSyncAccount _account;

  // Drive 앱 전용 숨김 폴더 이름 (spaces·parents 공통)
  static const _appDataFolder = 'appDataFolder';
  static const _jsonMimeType = 'application/json';

  // 한 번의 호출 상한 (느린 망에서 동기화가 앱을 붙잡지 않게)
  static const _requestTimeout = Duration(seconds: 20);

  @override
  Future<CloudSyncRead> read() async {
    final api = await _driveApi();
    if (api == null) return const CloudSyncReadFailed('unauthorized');
    try {
      final fileId = await _findFileId(api);
      if (fileId == null) return const CloudSyncReadEmpty();
      final media =
          await api.files
                  .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia)
                  .timeout(_requestTimeout)
              as drive.Media;
      final bytes = await media.stream
          .expand((chunk) => chunk)
          .toList()
          .timeout(_requestTimeout);
      return CloudSyncReadFound(utf8.decode(bytes));
    } on Object catch (error) {
      final reason = _reasonOf(error);
      Diagnostics.log('sync', 'drive read failed reason=$reason error=$error');
      return CloudSyncReadFailed(reason);
    }
  }

  @override
  Future<bool> write(String json) async {
    final api = await _driveApi();
    if (api == null) return false;
    try {
      final bytes = utf8.encode(json);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: _jsonMimeType,
      );
      final fileId = await _findFileId(api);
      if (fileId == null) {
        await api.files
            .create(
              drive.File(
                name: CloudSyncDocument.fileName,
                parents: const [_appDataFolder],
                mimeType: _jsonMimeType,
              ),
              uploadMedia: media,
            )
            .timeout(_requestTimeout);
      } else {
        await api.files
            .update(drive.File(), fileId, uploadMedia: media)
            .timeout(_requestTimeout);
      }
      return true;
    } on Object catch (error) {
      Diagnostics.log(
        'sync',
        'drive write failed reason=${_reasonOf(error)} error=$error',
      );
      return false;
    }
  }

  @override
  Future<bool> deleteAll() async {
    final api = await _driveApi();
    if (api == null) return false;
    try {
      final list = await api.files
          .list(spaces: _appDataFolder, $fields: 'files(id)')
          .timeout(_requestTimeout);
      for (final file in list.files ?? const <drive.File>[]) {
        await api.files.delete(file.id!).timeout(_requestTimeout);
      }
      Diagnostics.log(
        'sync',
        'drive data deleted files=${list.files?.length ?? 0}',
      );
      return true;
    } on Object catch (error) {
      Diagnostics.log(
        'sync',
        'drive delete failed reason=${_reasonOf(error)} error=$error',
      );
      return false;
    }
  }

  /// 동기화 파일 id (없으면 null)
  Future<String?> _findFileId(drive.DriveApi api) async {
    final list = await api.files
        .list(
          spaces: _appDataFolder,
          q: "name = '${CloudSyncDocument.fileName}' and trashed = false",
          $fields: 'files(id)',
          pageSize: 1,
        )
        .timeout(_requestTimeout);
    final files = list.files;
    return files == null || files.isEmpty ? null : files.first.id;
  }

  /// 로그인 헤더를 붙인 Drive 클라이언트. 로그인이 없으면 null
  Future<drive.DriveApi?> _driveApi() async {
    final headers = await _account.authHeaders();
    if (headers == null) {
      Diagnostics.log('sync', 'drive call skipped reason=no_auth');
      return null;
    }
    return drive.DriveApi(_AuthHeaderClient(headers));
  }

  /// 오류 > 고정 영문 사유
  static String _reasonOf(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    drive.DetailedApiRequestError(status: 401 || 403) => 'unauthorized',
    drive.DetailedApiRequestError(:final status) => 'http_$status',
    http.ClientException() => 'offline',
    _ => 'unknown',
  };
}

/// 모든 요청에 인증 헤더를 붙이는 http 클라이언트
class _AuthHeaderClient extends http.BaseClient {
  _AuthHeaderClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
