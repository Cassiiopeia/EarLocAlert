import '../../../core/diagnostics/diagnostics.dart';
import 'alert_place.dart';
import 'place_backup.dart';

/// 자동 백업 폴더 (#314): 사용자가 한 번 고른 폴더. 접근 권한 유지는 네이티브가 함
abstract interface class AutoBackupFolder {
  /// 폴더 고르기 창. 고른 폴더 이름, 취소·실패면 null
  Future<String?> pick();

  /// 고른 폴더 이름. 없거나 권한을 잃었으면 null
  Future<String?> name();

  /// 폴더 안 파일 덮어쓰기. 실패하면 false
  Future<bool> write({required String fileName, required String content});

  Future<void> clear();
}

/// 마지막 자동 백업 기록 (시각, 내용 서명)
abstract interface class AutoBackupStateStore {
  Future<DateTime?> lastBackupAtUtc();

  /// 마지막으로 쓴 장소 내용 (시각 제외) — 같으면 다시 쓰지 않음
  Future<String?> lastSignature();

  Future<void> saveWritten({
    required DateTime atUtc,
    required String signature,
  });

  Future<void> clear();
}

/// 자동 백업 결과 5가지: 씀, 폴더 없음, 장소 없음, 바뀐 것 없음, 실패
enum AutoBackupOutcome { written, noFolder, noPlaces, unchanged, failed }

/// 장소 > 백업 파일 쓰기 (#314): 검사 (폴더, 장소 0개, 변화 없음) > 쓰기 > 기록
///
/// 장소 0개는 쓰지 않음 — 재설치 직후 빈 목록이 좋은 백업을 덮어쓰지 않게.
class AutoBackupService {
  const AutoBackupService({required this.folder, required this.state});

  final AutoBackupFolder folder;
  final AutoBackupStateStore state;

  // 폴더에 쓰는 파일 이름 (불러오기에서 이 파일을 고르면 복원)
  static const fileName = 'earlocalert-places-auto.json';

  // 서명용 고정 시각: 내보낸 시각이 달라도 장소가 같으면 같은 서명
  static final _signatureEpoch = DateTime.utc(2000);

  Future<AutoBackupOutcome> backup(
    List<AlertPlace> places, {
    required DateTime nowUtc,
    required String appVersion,
    required String reason,
    bool force = false,
  }) async {
    if (places.isEmpty) return _skip(AutoBackupOutcome.noPlaces, reason);
    final folderName = await folder.name();
    if (folderName == null) return _skip(AutoBackupOutcome.noFolder, reason);

    final signature = PlaceBackup.encode(places, now: _signatureEpoch).json;
    if (!force && signature == await state.lastSignature()) {
      return _skip(AutoBackupOutcome.unchanged, reason);
    }

    final export = PlaceBackup.encode(
      places,
      now: nowUtc,
      appVersion: appVersion,
    );
    final isWritten = await folder.write(
      fileName: fileName,
      content: export.json,
    );
    if (!isWritten) {
      Diagnostics.log(
        'backup',
        'auto backup failed reason=$reason folder=$folderName',
      );
      return AutoBackupOutcome.failed;
    }
    await state.saveWritten(atUtc: nowUtc, signature: signature);
    Diagnostics.log(
      'backup',
      'auto backup written reason=$reason places=${export.placeCount} '
          'folder=$folderName',
    );
    return AutoBackupOutcome.written;
  }

  AutoBackupOutcome _skip(AutoBackupOutcome outcome, String reason) {
    Diagnostics.log(
      'backup',
      'auto backup skipped reason=$reason result=${outcome.name}',
    );
    return outcome;
  }
}
