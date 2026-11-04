import '../../../core/diagnostics/diagnostics.dart';
import 'alert_place.dart';
import 'cloud_sync.dart';
import 'cloud_sync_document.dart';
import 'cloud_sync_merge.dart';
import 'place_repository.dart';

/// 동기화 결과: 맞춤, 바뀐 것 없음, 프로 아님, 연결 안 됨, 읽기·쓰기 실패, 새 파일 버전, 빈 목록이라 안 올림, 가져오기 확인 대기
enum CloudSyncOutcome {
  synced,
  unchanged,
  notPro,
  notConnected,
  readFailed,
  writeFailed,
  newerSchema,
  skippedEmpty,
  awaitingImport,
}

/// 연결 결과: 취소, 가져오기 확인 필요, 연결 후 동기화 결과
sealed class CloudSyncConnectResult {
  const CloudSyncConnectResult();
}

final class CloudSyncConnectCancelled extends CloudSyncConnectResult {
  const CloudSyncConnectCancelled();
}

/// 이 기기엔 장소가 없고 Drive 엔 있음 > 사용자에게 물음
final class CloudSyncConnectNeedsImport extends CloudSyncConnectResult {
  const CloudSyncConnectNeedsImport({
    required this.remotePlaceCount,
    required this.deviceLabel,
    required this.savedAtUtc,
  });

  final int remotePlaceCount;
  final String deviceLabel;
  final DateTime savedAtUtc;
}

final class CloudSyncConnectDone extends CloudSyncConnectResult {
  const CloudSyncConnectDone(this.outcome);

  final CloudSyncOutcome outcome;
}

/// 구글 드라이브 동기화 흐름 (#330): 프로 확인 > 연결 확인 > 읽기 > 변경 감지·병합 > 적용 > 쓰기
///
/// 읽지 못하면 쓰지 않음. 로컬 장소 0개면 올리지 않음. 첫 읽기 전엔 빈 기기에 묻고 기다림
class CloudSyncService {
  CloudSyncService({
    required this.account,
    required this.remote,
    required this.store,
    required this.repository,
    required this.isPro,
    required this.nowUtc,
    required this.maximumPlaces,
    required this.deviceLabel,
  });

  final CloudSyncAccount account;
  final CloudSyncRemote remote;
  final CloudSyncStateStore store;
  final PlaceRepository repository;
  final bool Function() isPro;
  final DateTime Function() nowUtc;
  final int Function() maximumPlaces;

  /// 이 기기를 부르는 이름 (다른 기기의 가져오기 시트에 표시)
  final String deviceLabel;

  /// 진행 중 동기화 (겹쳐 돌면 장부가 엉킴 > 하나로 묶음)
  Future<CloudSyncOutcome>? _running;

  /// 동기화 1회 (겹친 호출은 진행 중인 것을 기다림)
  Future<CloudSyncOutcome> sync({required String reason}) {
    final running = _running;
    if (running != null) return running;
    final next = _syncOnce(reason).whenComplete(() => _running = null);
    _running = next;
    return next;
  }

  /// 연결: 로그인 > 저장 > 원격 확인 (빈 기기 + 원격 장소 > 확인 요청) > 동기화
  Future<CloudSyncConnectResult> connect() async {
    if (!isPro()) return const CloudSyncConnectDone(CloudSyncOutcome.notPro);
    final email = await account.signIn();
    if (email == null) return const CloudSyncConnectCancelled();
    await store.saveAccountEmail(email);
    Diagnostics.log('cloudsync', 'connected account=${_domainOf(email)}');

    final read = await remote.read();
    if (read is CloudSyncReadFound) {
      final decoded = CloudSyncDocument.fromJson(read.json);
      final localPlaces = await repository.findAll();
      if (decoded is CloudSyncDecodedOk &&
          decoded.document.placeCount > 0 &&
          localPlaces.isEmpty &&
          !await store.hasCompletedFirstRead()) {
        Diagnostics.log(
          'cloudsync',
          'import confirm needed remote_places=${decoded.document.placeCount}',
        );
        return CloudSyncConnectNeedsImport(
          remotePlaceCount: decoded.document.placeCount,
          deviceLabel: decoded.document.deviceLabel,
          savedAtUtc: decoded.document.updatedAt,
        );
      }
    }
    return CloudSyncConnectDone(await sync(reason: 'connected'));
  }

  /// 가져오기 확인 > 첫 읽기 완료로 표시 > 동기화 (빈 기기라 원격 장소를 전부 가져옴)
  Future<CloudSyncOutcome> confirmImport() async {
    await store.markFirstReadDone();
    Diagnostics.log('cloudsync', 'import confirmed');
    return sync(reason: 'import_confirmed');
  }

  /// 연결 끊기 (Drive 데이터 지우기 선택) > 로그아웃 > 로컬 상태 지움 (장소는 그대로)
  Future<void> disconnect({required bool deleteRemote}) async {
    if (deleteRemote) await remote.deleteAll();
    await account.signOut();
    await store.clear();
    Diagnostics.log('cloudsync', 'disconnected delete_remote=$deleteRemote');
  }

  Future<CloudSyncOutcome> _syncOnce(String reason) async {
    try {
      final outcome = await _runSteps();
      Diagnostics.log(
        'cloudsync',
        'sync done reason=$reason result=${outcome.name}',
      );
      return outcome;
    } on Object catch (error) {
      // 동기화 실패가 앱을 멈추면 안 됨 > 기록만
      Diagnostics.log('cloudsync', 'sync error reason=$reason error=$error');
      return CloudSyncOutcome.writeFailed;
    }
  }

  Future<CloudSyncOutcome> _runSteps() async {
    // 검사 (프로, 연결)
    if (!isPro()) return CloudSyncOutcome.notPro;
    if (await store.accountEmail() == null) {
      return CloudSyncOutcome.notConnected;
    }

    // 원격 읽기 (실패면 여기서 끝, 쓰지 않음)
    final read = await remote.read();
    final CloudSyncDocument? remoteDocument;
    switch (read) {
      case CloudSyncReadFailed():
        return CloudSyncOutcome.readFailed;
      case CloudSyncReadEmpty():
        remoteDocument = null;
      case CloudSyncReadFound(:final json):
        final decoded = CloudSyncDocument.fromJson(json);
        switch (decoded) {
          case CloudSyncDecodedFailure(error: CloudSyncDecodeError.newerSchema):
            return CloudSyncOutcome.newerSchema;
          case CloudSyncDecodedFailure(:final error):
            // 깨진 원격 파일은 덮어쓰지 않음 (사람이 확인할 기회를 남김)
            Diagnostics.log(
              'cloudsync',
              'remote unreadable error=${error.name}',
            );
            return CloudSyncOutcome.readFailed;
          case CloudSyncDecodedOk(:final document):
            remoteDocument = document;
        }
    }

    // 로컬 변화 감지 (첫 읽기 전·장부 유실이면 장부에 없는 장소는 시각 모름 > 원격이 이김)
    final now = nowUtc();
    final localPlaces = await repository.findAll();
    final previousLedger = await store.ledger();
    final isFirstRead = !await store.hasCompletedFirstRead();
    final ledger = CloudSyncMerge.trackLocal(
      places: localPlaces,
      previous: previousLedger,
      nowUtc: now,
      unknownPlacesUpdatedAt: isFirstRead || previousLedger.isEmpty
          ? CloudSyncMerge.unknownEditTime
          : null,
    );

    // 재설치 보호: 첫 읽기 전 빈 기기 + 원격 장소 > 사용자 확인까지 대기
    if (isFirstRead &&
        localPlaces.isEmpty &&
        (remoteDocument?.placeCount ?? 0) > 0) {
      return CloudSyncOutcome.awaitingImport;
    }

    // 병합 > 적용
    final result = CloudSyncMerge.merge(
      local: ledger,
      localPlaces: localPlaces,
      remote: remoteDocument,
      maximumPlaces: maximumPlaces(),
    );
    await _apply(result);
    await store.saveLedger(result.ledger);
    await store.markFirstReadDone();

    // 쓰기 (로컬 장소 0개면 절대 올리지 않음)
    final placeCountAfter =
        localPlaces.length + result.toSave.length - result.toDelete.length;
    final shouldWrite = result.hasLocalChanges || remoteDocument == null;
    if (shouldWrite && placeCountAfter <= 0) {
      return CloudSyncOutcome.skippedEmpty;
    }
    if (shouldWrite) {
      final document = CloudSyncDocument(
        updatedAt: now,
        deviceLabel: deviceLabel,
        entries: result.mergedEntries,
      );
      if (!await remote.write(document.toJson())) {
        return CloudSyncOutcome.writeFailed;
      }
    }
    await store.saveLastSyncedAt(now);
    return shouldWrite || result.hasRemoteChanges
        ? CloudSyncOutcome.synced
        : CloudSyncOutcome.unchanged;
  }

  /// 병합 결과 적용: 저장(가져옴·원격 수정) > 삭제. 저장소 경로라 지오펜스도 다시 맞춰짐
  Future<void> _apply(CloudSyncMergeResult result) async {
    for (final AlertPlace place in result.toSave) {
      await repository.save(place);
    }
    for (final id in result.toDelete) {
      await repository.delete(id);
    }
    Diagnostics.log(
      'cloudsync',
      'merge applied imported=${result.toSave.length} '
          'deleted=${result.toDelete.length} '
          'dropped_over_limit=${result.droppedOverLimit} '
          'upload=${result.hasLocalChanges}',
    );
  }

  /// 로그에는 계정 도메인만
  static String _domainOf(String email) {
    final at = email.indexOf('@');
    return at < 0 ? 'unknown' : email.substring(at + 1);
  }
}
