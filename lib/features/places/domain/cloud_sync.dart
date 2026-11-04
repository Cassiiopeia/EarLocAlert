import 'cloud_sync_merge.dart';

/// 구글 계정 연결 (#330): 로그인·조용한 재로그인·로그아웃·Drive 호출 헤더
abstract interface class CloudSyncAccount {
  /// 로그인 창 > 이메일. 취소·실패면 null
  Future<String?> signIn();

  /// 창 없이 이전 로그인 복구 > 이메일. 없으면 null
  Future<String?> signInSilently();

  Future<void> signOut();

  /// Drive 호출용 인증 헤더. 로그인이 없거나 만료면 null
  Future<Map<String, String>?> authHeaders();
}

/// Drive appDataFolder 의 동기화 파일 한 개 읽기·쓰기·지우기
abstract interface class CloudSyncRemote {
  Future<CloudSyncRead> read();

  /// 파일 덮어쓰기 (없으면 만듦). 실패하면 false
  Future<bool> write(String json);

  /// 앱 폴더 파일 전부 지우기 ("Drive 데이터 지우기")
  Future<bool> deleteAll();
}

/// 원격 읽기 결과 3가지: 파일 있음, 파일 없음, 읽기 실패
sealed class CloudSyncRead {
  const CloudSyncRead();
}

final class CloudSyncReadFound extends CloudSyncRead {
  const CloudSyncReadFound(this.json);

  final String json;
}

final class CloudSyncReadEmpty extends CloudSyncRead {
  const CloudSyncReadEmpty();
}

final class CloudSyncReadFailed extends CloudSyncRead {
  const CloudSyncReadFailed(this.reason);

  /// 고정 영문 사유 (로그용: offline, unauthorized, http_500 …)
  final String reason;
}

/// 동기화 로컬 상태: 장부, 연결 계정, 마지막 동기화, 첫 읽기 완료 여부
abstract interface class CloudSyncStateStore {
  Future<List<SyncLedgerEntry>> ledger();

  Future<void> saveLedger(List<SyncLedgerEntry> entries);

  Future<String?> accountEmail();

  Future<void> saveAccountEmail(String? email);

  Future<DateTime?> lastSyncedAtUtc();

  Future<void> saveLastSyncedAt(DateTime atUtc);

  /// 연결 뒤 원격을 한 번이라도 읽고 맞췄는가 (재설치 보호: 그 전엔 올리지 않음)
  Future<bool> hasCompletedFirstRead();

  Future<void> markFirstReadDone();

  Future<void> clear();
}
