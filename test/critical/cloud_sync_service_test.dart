import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_document.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_merge.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_service.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// 동기화 흐름 (#330): 읽지 못한 채 쓰거나, 재설치 직후 빈 목록을 올리면 Drive 의 장소가 사라진다
void main() {
  final now = DateTime.utc(2026, 11, 5, 12);

  AlertPlace place(String id, {String name = 'Place'}) => AlertPlace(
    id: id,
    name: name,
    latitude: 37.5,
    longitude: 127,
    radiusMeters: 150,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026),
  );

  String remoteJson(List<AlertPlace> places, {DateTime? updatedAt}) =>
      CloudSyncDocument(
        updatedAt: updatedAt ?? DateTime.utc(2026, 11, 4),
        deviceLabel: 'Pixel 8',
        entries: [
          for (final value in places)
            CloudSyncEntry(
              syncId: value.id,
              updatedAt: updatedAt ?? DateTime.utc(2026, 11, 4),
              place: value,
            ),
        ],
      ).toJson();

  late _FakeAccount account;
  late _FakeRemote remote;
  late _MemoryStateStore store;
  late _MemoryPlaceRepository repository;
  var isPro = true;

  CloudSyncService service() => CloudSyncService(
    account: account,
    remote: remote,
    store: store,
    repository: repository,
    isPro: () => isPro,
    nowUtc: () => now,
    maximumPlaces: () => 30,
    deviceLabel: 'Android',
  );

  setUp(() {
    account = _FakeAccount();
    remote = _FakeRemote();
    store = _MemoryStateStore();
    repository = _MemoryPlaceRepository();
    isPro = true;
  });

  test('not pro returns notPro without network calls', () async {
    isPro = false;
    store.email = 'user@gmail.com';

    final outcome = await service().sync(reason: 'test');

    expect(outcome, CloudSyncOutcome.notPro);
    expect(remote.readCount, 0);
    expect(remote.writes, isEmpty);
  });

  test('read failure does not write', () async {
    store.email = 'user@gmail.com';
    store.firstReadDone = true;
    repository.places['a'] = place('a');
    remote.nextRead = const CloudSyncReadFailed('offline');

    final outcome = await service().sync(reason: 'test');

    expect(outcome, CloudSyncOutcome.readFailed);
    expect(remote.writes, isEmpty);
  });

  test(
    'empty local with remote places asks confirm and writes nothing',
    () async {
      remote.nextRead = CloudSyncReadFound(
        remoteJson([place('a'), place('b')]),
      );

      final result = await service().connect();

      expect(result, isA<CloudSyncConnectNeedsImport>());
      final needsImport = result as CloudSyncConnectNeedsImport;
      expect(needsImport.remotePlaceCount, 2);
      expect(needsImport.deviceLabel, 'Pixel 8');
      expect(remote.writes, isEmpty);
      expect(repository.places, isEmpty);
      expect(store.email, 'user@gmail.com');
    },
  );

  test('confirm import saves remote places through repository', () async {
    remote.nextRead = CloudSyncReadFound(
      remoteJson([place('a', name: 'Home')]),
    );
    await service().connect();

    final outcome = await service().confirmImport();

    expect(outcome, CloudSyncOutcome.synced);
    expect(repository.places['a']?.name, 'Home');
    expect(store.firstReadDone, isTrue);
  });

  test(
    'sync before import confirm keeps waiting while local is empty',
    () async {
      store.email = 'user@gmail.com';
      remote.nextRead = CloudSyncReadFound(remoteJson([place('a')]));

      final outcome = await service().sync(reason: 'resumed');

      expect(outcome, CloudSyncOutcome.awaitingImport);
      expect(repository.places, isEmpty);
      expect(remote.writes, isEmpty);
    },
  );

  test('merge result is applied through repository save and delete', () async {
    store.email = 'user@gmail.com';
    store.firstReadDone = true;
    repository.places['local'] = place('local');
    repository.places['gone'] = place('gone');
    store.entries = CloudSyncMerge.trackLocal(
      places: [place('local'), place('gone')],
      previous: const [],
      nowUtc: DateTime.utc(2026, 11, 1),
    );
    remote.nextRead = CloudSyncReadFound(
      CloudSyncDocument(
        updatedAt: DateTime.utc(2026, 11, 4),
        deviceLabel: 'iPhone',
        entries: [
          CloudSyncEntry(
            syncId: 'gone',
            updatedAt: DateTime.utc(2026, 11, 4),
            isDeleted: true,
          ),
          CloudSyncEntry(
            syncId: 'new',
            updatedAt: DateTime.utc(2026, 11, 4),
            place: place('new'),
          ),
        ],
      ).toJson(),
    );

    final outcome = await service().sync(reason: 'test');

    expect(outcome, CloudSyncOutcome.synced);
    expect(repository.places.keys, unorderedEquals(['local', 'new']));
    expect(remote.writes, hasLength(1));
    final written =
        CloudSyncDocument.fromJson(remote.writes.single) as CloudSyncDecodedOk;
    expect(
      written.document.entries.map((entry) => entry.syncId),
      unorderedEquals(['local', 'gone', 'new']),
    );
  });

  test('newer remote schema stops with newerSchema', () async {
    store.email = 'user@gmail.com';
    store.firstReadDone = true;
    repository.places['a'] = place('a');
    remote.nextRead = const CloudSyncReadFound(
      '{"format":"earlocalert-sync","schemaVersion":99,"updatedAt":"2026-11-04T00:00:00Z","places":[]}',
    );

    final outcome = await service().sync(reason: 'test');

    expect(outcome, CloudSyncOutcome.newerSchema);
    expect(remote.writes, isEmpty);
  });

  test('empty local after merge never uploads', () async {
    store.email = 'user@gmail.com';
    store.firstReadDone = true;
    remote.nextRead = const CloudSyncReadEmpty();

    final outcome = await service().sync(reason: 'test');

    expect(outcome, CloudSyncOutcome.skippedEmpty);
    expect(remote.writes, isEmpty);
  });

  test('cancelled sign in stays disconnected', () async {
    account.nextEmail = null;

    final result = await service().connect();

    expect(result, isA<CloudSyncConnectCancelled>());
    expect(store.email, isNull);
  });

  test('disconnect with deleteRemote clears drive and local state', () async {
    store.email = 'user@gmail.com';
    store.firstReadDone = true;

    await service().disconnect(deleteRemote: true);

    expect(remote.deleteAllCount, 1);
    expect(account.signedOut, isTrue);
    expect(store.email, isNull);
    expect(store.firstReadDone, isFalse);
  });
}

class _FakeAccount implements CloudSyncAccount {
  String? nextEmail = 'user@gmail.com';
  bool signedOut = false;

  @override
  Future<String?> signIn() async => nextEmail;

  @override
  Future<String?> signInSilently() async => nextEmail;

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Future<Map<String, String>?> authHeaders() async => const {};
}

class _FakeRemote implements CloudSyncRemote {
  CloudSyncRead nextRead = const CloudSyncReadEmpty();
  final writes = <String>[];
  int readCount = 0;
  int deleteAllCount = 0;

  @override
  Future<CloudSyncRead> read() async {
    readCount++;
    return nextRead;
  }

  @override
  Future<bool> write(String json) async {
    writes.add(json);
    nextRead = CloudSyncReadFound(json);
    return true;
  }

  @override
  Future<bool> deleteAll() async {
    deleteAllCount++;
    return true;
  }
}

class _MemoryStateStore implements CloudSyncStateStore {
  List<SyncLedgerEntry> entries = const [];
  String? email;
  DateTime? lastSynced;
  bool firstReadDone = false;

  @override
  Future<List<SyncLedgerEntry>> ledger() async => entries;

  @override
  Future<void> saveLedger(List<SyncLedgerEntry> value) async => entries = value;

  @override
  Future<String?> accountEmail() async => email;

  @override
  Future<void> saveAccountEmail(String? value) async => email = value;

  @override
  Future<DateTime?> lastSyncedAtUtc() async => lastSynced;

  @override
  Future<void> saveLastSyncedAt(DateTime atUtc) async => lastSynced = atUtc;

  @override
  Future<bool> hasCompletedFirstRead() async => firstReadDone;

  @override
  Future<void> markFirstReadDone() async => firstReadDone = true;

  @override
  Future<void> clear() async {
    entries = const [];
    email = null;
    lastSynced = null;
    firstReadDone = false;
  }
}

class _MemoryPlaceRepository implements PlaceRepository {
  final places = <String, AlertPlace>{};

  @override
  Future<List<AlertPlace>> findAll() async => places.values.toList();

  @override
  Future<void> save(AlertPlace place) async => places[place.id] = place;

  @override
  Future<void> delete(String id) async => places.remove(id);

  @override
  Future<AlertPlace?> findById(String id) async => places[id];

  @override
  Future<int> count() async => places.length;

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      places.values.where((value) => value.enabled).toList();

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<void> setEnabledMany(Map<String, bool> enabledById) async {}

  @override
  Stream<List<AlertPlace>> watchAll() => const Stream.empty();
}
