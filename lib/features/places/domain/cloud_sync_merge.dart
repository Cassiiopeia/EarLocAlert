import 'dart:convert';

import 'alert_place.dart';
import 'cloud_sync_document.dart';
import 'place_backup.dart';

/// 로컬 변경 장부 한 줄 (#330): 장소별 내용 서명, 마지막 수정·삭제 시각
///
/// 장소 테이블에 수정 시각이 없어 여기서 변화를 감지함 (서명이 바뀐 순간 = 수정)
class SyncLedgerEntry {
  const SyncLedgerEntry({
    required this.syncId,
    required this.signature,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String syncId;

  /// 장소 내용 서명 ([CloudSyncMerge.signatureOf]). 삭제면 빈 문자열
  final String signature;
  final DateTime updatedAt;
  final bool isDeleted;
}

/// 병합 결과: 로컬에 저장·삭제할 것, Drive 에 쓸 항목, 새 장부, 변화 여부
class CloudSyncMergeResult {
  const CloudSyncMergeResult({
    required this.toSave,
    required this.toDelete,
    required this.mergedEntries,
    required this.ledger,
    required this.droppedOverLimit,
    required this.hasRemoteChanges,
    required this.hasLocalChanges,
  });

  /// 원격이 이겨 로컬에 저장할 장소 (새로 가져옴 포함)
  final List<AlertPlace> toSave;

  /// 원격 삭제가 이겨 로컬에서 지울 장소 id
  final List<String> toDelete;

  /// Drive 에 쓸 전체 항목 (상한으로 가져오지 않은 장소도 남김)
  final List<CloudSyncEntry> mergedEntries;

  /// 병합 뒤 로컬 장부
  final List<SyncLedgerEntry> ledger;

  /// 상한 때문에 가져오지 않은 장소 수
  final int droppedOverLimit;

  /// 로컬이 바뀜 (저장·삭제 있음)
  final bool hasRemoteChanges;

  /// Drive 를 다시 써야 함 (로컬이 이긴 항목 있음)
  final bool hasLocalChanges;
}

/// 동기화 병합 규칙 (#330): 장소 단위 최근 수정이 이김, 삭제는 표시로 비교
abstract final class CloudSyncMerge {
  /// 삭제 표시 보존 기간 (90일). 그 뒤엔 다른 기기의 옛 사본이 되살릴 수 있음
  static const tombstoneRetention = Duration(days: 90);

  /// 장소 내용 서명 (백업 파일과 같은 필드 > id·생성 시각 제외)
  static String signatureOf(AlertPlace place) =>
      jsonEncode(PlaceBackup.encodePlace(place));

  /// 로컬 변화 감지: 서명이 바뀐 장소 > 지금 시각, 사라진 장소 > 삭제 표시, 오래된 삭제 표시 제거
  static List<SyncLedgerEntry> trackLocal({
    required List<AlertPlace> places,
    required List<SyncLedgerEntry> previous,
    required DateTime nowUtc,
  }) {
    final previousById = {for (final entry in previous) entry.syncId: entry};
    final tracked = <SyncLedgerEntry>[];

    // 지금 있는 장소 (그대로면 시각 유지)
    for (final place in places) {
      final signature = signatureOf(place);
      final before = previousById.remove(place.id);
      final isUnchanged =
          before != null && !before.isDeleted && before.signature == signature;
      tracked.add(
        isUnchanged
            ? before
            : SyncLedgerEntry(
                syncId: place.id,
                signature: signature,
                updatedAt: nowUtc,
              ),
      );
    }

    // 사라진 장소 (이미 삭제 표시면 보존 기간만 확인)
    for (final before in previousById.values) {
      if (before.isDeleted) {
        final isExpired =
            nowUtc.difference(before.updatedAt) > tombstoneRetention;
        if (!isExpired) tracked.add(before);
        continue;
      }
      tracked.add(
        SyncLedgerEntry(
          syncId: before.syncId,
          signature: '',
          updatedAt: nowUtc,
          isDeleted: true,
        ),
      );
    }
    return tracked;
  }

  /// 로컬 장부·장소 <-> 원격 문서 병합. [remote] null = Drive 에 파일 없음
  static CloudSyncMergeResult merge({
    required List<SyncLedgerEntry> local,
    required List<AlertPlace> localPlaces,
    required CloudSyncDocument? remote,
    required int maximumPlaces,
  }) {
    final localById = {for (final entry in local) entry.syncId: entry};
    final placeById = {for (final place in localPlaces) place.id: place};
    final remoteById = {
      for (final entry in remote?.entries ?? const <CloudSyncEntry>[])
        entry.syncId: entry,
    };

    final merged = <CloudSyncEntry>[];
    final imports = <CloudSyncEntry>[];
    final toDelete = <String>[];
    var hasLocalChanges = false;

    for (final syncId in {...localById.keys, ...remoteById.keys}) {
      final mine = localById[syncId];
      final theirs = remoteById[syncId];

      // 한쪽에만 있음
      if (theirs == null) {
        merged.add(_entryFromLocal(mine!, placeById[syncId]));
        hasLocalChanges = true;
        continue;
      }
      if (mine == null) {
        merged.add(theirs);
        if (!theirs.isDeleted) imports.add(theirs);
        continue;
      }

      // 둘 다 있음: 늦은 쪽이 이김 (같으면 로컬)
      if (theirs.updatedAt.isAfter(mine.updatedAt)) {
        merged.add(theirs);
        if (theirs.isDeleted) {
          if (!mine.isDeleted) toDelete.add(syncId);
        } else if (mine.isDeleted ||
            mine.signature != signatureOf(theirs.place!)) {
          imports.add(theirs);
        }
        continue;
      }
      merged.add(_entryFromLocal(mine, placeById[syncId]));
      if (_differs(mine, theirs)) hasLocalChanges = true;
    }

    // 상한: 살아 있는 항목 중 최근 수정 순으로 [maximumPlaces] 개까지만 로컬에 둠
    final liveByRecency = merged.where((entry) => !entry.isDeleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final keptIds = liveByRecency
        .take(maximumPlaces)
        .map((entry) => entry.syncId)
        .toSet();
    final toSave = [
      for (final entry in imports)
        if (keptIds.contains(entry.syncId)) entry.place!,
    ];
    final droppedOverLimit = imports.length - toSave.length;
    final skippedIds = {
      for (final entry in imports)
        if (!keptIds.contains(entry.syncId)) entry.syncId,
    };

    return CloudSyncMergeResult(
      toSave: toSave,
      toDelete: toDelete,
      mergedEntries: merged,
      ledger: [
        for (final entry in merged)
          // 가져오지 않은 장소는 장부에 넣지 않음 (넣으면 다음 동기화가 삭제로 봄)
          if (!skippedIds.contains(entry.syncId)) _ledgerFrom(entry),
      ],
      droppedOverLimit: droppedOverLimit,
      hasRemoteChanges: toSave.isNotEmpty || toDelete.isNotEmpty,
      hasLocalChanges: hasLocalChanges,
    );
  }

  static CloudSyncEntry _entryFromLocal(
    SyncLedgerEntry entry,
    AlertPlace? place,
  ) => CloudSyncEntry(
    syncId: entry.syncId,
    updatedAt: entry.updatedAt,
    isDeleted: entry.isDeleted || place == null,
    place: entry.isDeleted ? null : place,
  );

  /// 로컬이 이긴 항목이 원격과 다른가 (시각·삭제 여부·내용)
  static bool _differs(SyncLedgerEntry mine, CloudSyncEntry theirs) {
    if (mine.isDeleted != theirs.isDeleted) return true;
    if (!mine.updatedAt.isAtSameMomentAs(theirs.updatedAt)) return true;
    if (mine.isDeleted) return false;
    return mine.signature != signatureOf(theirs.place!);
  }

  static SyncLedgerEntry _ledgerFrom(CloudSyncEntry entry) => SyncLedgerEntry(
    syncId: entry.syncId,
    signature: entry.isDeleted ? '' : signatureOf(entry.place!),
    updatedAt: entry.updatedAt,
    isDeleted: entry.isDeleted,
  );
}
