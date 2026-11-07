import 'dart:convert';

import 'alert_place.dart';
import 'place_backup.dart';

/// 동기화 파일 한 건 (#330): 고정 id, 수정 시각, 삭제 표시 (삭제면 장소 없음)
class CloudSyncEntry {
  const CloudSyncEntry({
    required this.syncId,
    required this.updatedAt,
    this.isDeleted = false,
    this.place,
  });

  /// 장소 id 그대로 (기기가 달라도 같은 장소를 알아봄)
  final String syncId;

  /// 마지막 수정·삭제 시각 (UTC)
  final DateTime updatedAt;
  final bool isDeleted;
  final AlertPlace? place;
}

/// Drive appDataFolder 의 `earlocalert-sync.json` 내용 (#330)
///
/// 장소 필드는 [PlaceBackup.encodePlace] 와 같은 모양 (단일 원본)
class CloudSyncDocument {
  const CloudSyncDocument({
    required this.updatedAt,
    required this.deviceLabel,
    required this.entries,
  });

  /// 우리 동기화 파일 표식
  static const formatName = 'earlocalert-sync';

  /// 지금 쓰고 읽는 모양의 버전
  static const schemaVersion = 1;

  /// Drive 파일 이름
  static const fileName = 'earlocalert-sync.json';

  final DateTime updatedAt;

  /// 마지막으로 쓴 기기 이름 (가져오기 시트에 표시)
  final String deviceLabel;
  final List<CloudSyncEntry> entries;

  /// 살아 있는 장소 수 (삭제 표시 제외)
  int get placeCount => entries.where((entry) => !entry.isDeleted).length;

  String toJson() => jsonEncode({
    'format': formatName,
    'schemaVersion': schemaVersion,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deviceLabel': deviceLabel,
    'places': [
      for (final entry in entries)
        {
          'syncId': entry.syncId,
          'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
          'deleted': entry.isDeleted,
          if (!entry.isDeleted && entry.place != null)
            'place': {
              ...PlaceBackup.encodePlace(entry.place!),
              'createdAt': entry.place!.createdAt.toUtc().toIso8601String(),
            },
        },
    ],
  });

  /// 파일 내용 읽기. 던지지 않음: 깨진 파일은 실패, 깨진 항목은 세고 건너뜀
  static CloudSyncDecoded fromJson(String raw) {
    final Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException {
      return const CloudSyncDecodedFailure(CloudSyncDecodeError.notJson);
    }
    if (root is! Map<String, Object?> || root['format'] != formatName) {
      return const CloudSyncDecodedFailure(CloudSyncDecodeError.notSyncFile);
    }
    final version = root['schemaVersion'];
    final list = root['places'];
    final updatedAt = _parseTime(root['updatedAt']);
    if (version is! int || list is! List<Object?> || updatedAt == null) {
      return const CloudSyncDecodedFailure(CloudSyncDecodeError.notSyncFile);
    }
    // 새 버전 파일은 모르는 필드가 있을 수 있음 > 잘못 덮어쓰느니 손대지 않음
    if (version > schemaVersion) {
      return const CloudSyncDecodedFailure(CloudSyncDecodeError.newerSchema);
    }

    final entries = <CloudSyncEntry>[];
    var invalid = 0;
    for (final entryJson in list) {
      final entry = _decodeEntry(entryJson);
      if (entry == null) {
        invalid++;
      } else {
        entries.add(entry);
      }
    }
    return CloudSyncDecodedOk(
      CloudSyncDocument(
        updatedAt: updatedAt,
        deviceLabel: root['deviceLabel'] is String
            ? root['deviceLabel'] as String
            : '',
        entries: entries,
      ),
      invalidCount: invalid,
    );
  }

  /// 항목 하나: 필수값(syncId, 시각) 확인 > 삭제면 표시만 > 아니면 장소 검증
  static CloudSyncEntry? _decodeEntry(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final syncId = item['syncId'];
    final updatedAt = _parseTime(item['updatedAt']);
    if (syncId is! String || syncId.isEmpty || updatedAt == null) return null;
    if (item['deleted'] == true) {
      return CloudSyncEntry(
        syncId: syncId,
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }
    final rawPlace = item['place'];
    if (rawPlace is! Map<String, Object?>) return null;
    final place = PlaceBackup.decodePlace(
      rawPlace,
      id: syncId,
      createdAt: _parseTime(rawPlace['createdAt']) ?? updatedAt,
    );
    if (place == null) return null;
    return CloudSyncEntry(syncId: syncId, updatedAt: updatedAt, place: place);
  }

  static DateTime? _parseTime(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// 읽기 실패 3가지: JSON 아님, 우리 파일 아님, 이 앱보다 새 버전
enum CloudSyncDecodeError { notJson, notSyncFile, newerSchema }

sealed class CloudSyncDecoded {
  const CloudSyncDecoded();
}

final class CloudSyncDecodedOk extends CloudSyncDecoded {
  const CloudSyncDecodedOk(this.document, {this.invalidCount = 0});

  final CloudSyncDocument document;

  /// 검증을 통과하지 못해 건너뛴 항목 수
  final int invalidCount;
}

final class CloudSyncDecodedFailure extends CloudSyncDecoded {
  const CloudSyncDecodedFailure(this.error);

  final CloudSyncDecodeError error;
}
