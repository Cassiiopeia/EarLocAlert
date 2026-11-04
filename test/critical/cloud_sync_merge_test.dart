import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_document.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

// 동기화 병합 (#330): 지운 장소가 되살아나거나, 빈 목록이 좋은 데이터를 덮으면 장소가 사라진다
void main() {
  final t0 = DateTime.utc(2026, 11, 1);
  final t1 = DateTime.utc(2026, 11, 2);
  final t2 = DateTime.utc(2026, 11, 3);

  AlertPlace place(String id, {String name = 'Place', int radius = 150}) =>
      AlertPlace(
        id: id,
        name: name,
        latitude: 37.5,
        longitude: 127,
        radiusMeters: radius,
        direction: AlertDirection.enter,
        createdAt: t0,
      );

  SyncLedgerEntry ledgerOf(
    AlertPlace value,
    DateTime updatedAt, {
    bool isDeleted = false,
  }) => SyncLedgerEntry(
    syncId: value.id,
    signature: CloudSyncMerge.signatureOf(value),
    updatedAt: updatedAt,
    isDeleted: isDeleted,
  );

  CloudSyncDocument remoteOf(List<CloudSyncEntry> entries) =>
      CloudSyncDocument(updatedAt: t1, deviceLabel: 'other', entries: entries);

  group('trackLocal', () {
    test('unchanged places keep updatedAt', () {
      final home = place('a');
      final first = CloudSyncMerge.trackLocal(
        places: [home],
        previous: const [],
        nowUtc: t0,
      );
      final second = CloudSyncMerge.trackLocal(
        places: [home],
        previous: first,
        nowUtc: t2,
      );

      expect(second.single.updatedAt, t0);
    });

    test('edited place gets new updatedAt', () {
      final before = [ledgerOf(place('a'), t0)];

      final after = CloudSyncMerge.trackLocal(
        places: [place('a', radius: 300)],
        previous: before,
        nowUtc: t2,
      );

      expect(after.single.updatedAt, t2);
    });

    test('removed place becomes tombstone at now', () {
      final before = [ledgerOf(place('a'), t0)];

      final after = CloudSyncMerge.trackLocal(
        places: const [],
        previous: before,
        nowUtc: t2,
      );

      expect(after.single.isDeleted, isTrue);
      expect(after.single.updatedAt, t2);
    });

    test('tombstones older than 90 days are pruned', () {
      final before = [ledgerOf(place('a'), t0, isDeleted: true)];

      final after = CloudSyncMerge.trackLocal(
        places: const [],
        previous: before,
        nowUtc: t0.add(const Duration(days: 91)),
      );

      expect(after, isEmpty);
    });
  });

  group('merge', () {
    test('local only is kept and uploaded', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t1)],
        localPlaces: [home],
        remote: remoteOf(const []),
        maximumPlaces: 30,
      );

      expect(result.toSave, isEmpty);
      expect(result.toDelete, isEmpty);
      expect(result.hasLocalChanges, isTrue);
      expect(result.mergedEntries.single.syncId, 'a');
    });

    test('remote only non deleted is imported', () {
      final office = place('b', name: 'Office');
      final result = CloudSyncMerge.merge(
        local: const [],
        localPlaces: const [],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'b', updatedAt: t1, place: office),
        ]),
        maximumPlaces: 30,
      );

      expect(result.toSave.single.name, 'Office');
      expect(result.hasRemoteChanges, isTrue);
      expect(result.hasLocalChanges, isFalse);
    });

    test('both present newer updatedAt wins', () {
      final localHome = place('a', name: 'Local');
      final remoteHome = place('a', name: 'Remote');

      final remoteWins = CloudSyncMerge.merge(
        local: [ledgerOf(localHome, t0)],
        localPlaces: [localHome],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, place: remoteHome),
        ]),
        maximumPlaces: 30,
      );
      final localWins = CloudSyncMerge.merge(
        local: [ledgerOf(localHome, t2)],
        localPlaces: [localHome],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, place: remoteHome),
        ]),
        maximumPlaces: 30,
      );

      expect(remoteWins.toSave.single.name, 'Remote');
      expect(localWins.toSave, isEmpty);
      expect(localWins.mergedEntries.single.place?.name, 'Local');
      expect(localWins.hasLocalChanges, isTrue);
    });

    test('local tombstone newer than remote edit deletes', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t2, isDeleted: true)],
        localPlaces: const [],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, place: home),
        ]),
        maximumPlaces: 30,
      );

      expect(result.toSave, isEmpty);
      expect(result.mergedEntries.single.isDeleted, isTrue);
      expect(result.hasLocalChanges, isTrue);
    });

    test('remote edit newer than local tombstone revives', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t0, isDeleted: true)],
        localPlaces: const [],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, place: home),
        ]),
        maximumPlaces: 30,
      );

      expect(result.toSave.single.id, 'a');
    });

    test('remote tombstone newer than local edit deletes locally', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t0)],
        localPlaces: [home],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, isDeleted: true),
        ]),
        maximumPlaces: 30,
      );

      expect(result.toDelete, ['a']);
      expect(result.mergedEntries.single.isDeleted, isTrue);
    });

    test('local edit newer than remote tombstone keeps place', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t2)],
        localPlaces: [home],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, isDeleted: true),
        ]),
        maximumPlaces: 30,
      );

      expect(result.toDelete, isEmpty);
      expect(result.mergedEntries.single.isDeleted, isFalse);
    });

    test(
      'over limit keeps most recently updated and reports dropped count',
      () {
        final result = CloudSyncMerge.merge(
          local: const [],
          localPlaces: const [],
          remote: remoteOf([
            CloudSyncEntry(syncId: 'old', updatedAt: t0, place: place('old')),
            CloudSyncEntry(syncId: 'mid', updatedAt: t1, place: place('mid')),
            CloudSyncEntry(syncId: 'new', updatedAt: t2, place: place('new')),
          ]),
          maximumPlaces: 2,
        );

        expect(
          result.toSave.map((value) => value.id),
          unorderedEquals(['mid', 'new']),
        );
        expect(result.droppedOverLimit, 1);
      },
    );

    test('no remote file keeps local and uploads', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t0)],
        localPlaces: [home],
        remote: null,
        maximumPlaces: 30,
      );

      expect(result.hasLocalChanges, isTrue);
      expect(result.toSave, isEmpty);
    });

    test('identical sides report no changes', () {
      final home = place('a');
      final result = CloudSyncMerge.merge(
        local: [ledgerOf(home, t1)],
        localPlaces: [home],
        remote: remoteOf([
          CloudSyncEntry(syncId: 'a', updatedAt: t1, place: home),
        ]),
        maximumPlaces: 30,
      );

      expect(result.hasLocalChanges, isFalse);
      expect(result.hasRemoteChanges, isFalse);
    });
  });
}
