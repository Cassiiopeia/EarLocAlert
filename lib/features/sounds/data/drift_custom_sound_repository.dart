import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/domain/id_generator.dart';
import '../domain/custom_sound.dart';
import '../domain/custom_sound_repository.dart';
import '../domain/sound_validator.dart';
import 'custom_sound_file.dart';

/// Drift + 파일 시스템 기반 [CustomSoundRepository] 구현 (이슈 #121)
///
/// **행과 파일이 함께 움직인다.** 어느 한쪽만 남는 상태를 최대한 피하되,
/// 피할 수 없을 때는 **행이 없고 파일이 남는 쪽**을 택한다 — 목록에
/// 보이는데 소리가 안 나는 것보다 낫고, 남은 파일은 나중에 청소할 수 있다.
class DriftCustomSoundRepository implements CustomSoundRepository {
  DriftCustomSoundRepository(
    this._db, {
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator ?? IdGenerator.generate,
       _clock = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final AppDatabase _db;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  @override
  Future<List<CustomSound>> findAll() async {
    final query = _db.select(_db.customSounds)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<CustomSound?> findById(String id) async {
    final row = await _findRow(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> count() async {
    final countExp = _db.customSounds.id.count();
    final query = _db.selectOnly(_db.customSounds)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<CustomSound> add({
    required String sourcePath,
    required String displayName,
    required Duration duration,
  }) async {
    final id = _idGenerator();
    final fileExtension = SoundValidator.extensionOf(displayName);
    final target = await CustomSoundFile.resolve(id, fileExtension);

    // 원본을 참조하지 않고 복사한다 — 재생 시점이 백그라운드라
    // 그때 원본에 접근할 수 있다고 가정할 수 없다
    await File(sourcePath).copy(target.path);

    final sound = CustomSound(
      id: id,
      displayName: displayName,
      fileExtension: fileExtension,
      duration: duration,
      sizeBytes: await target.length(),
      createdAt: _clock(),
    );

    try {
      await _db.into(_db.customSounds).insert(_toRow(sound));
    } on Object catch (error) {
      // 행이 없으면 목록에 안 나오는 파일이 용량만 먹는다
      await _deleteFileQuietly(target);
      Diagnostics.log('sound', '음원 등록 실패 name=$displayName 사유=$error');
      rethrow;
    }

    Diagnostics.log(
      'sound',
      '음원 등록 id=$id name=$displayName '
          '크기=${sound.sizeBytes}B 길이=${duration.inMilliseconds}ms',
    );
    return sound;
  }

  @override
  Future<void> delete(String id) async {
    final row = await _findRow(id);
    if (row == null) {
      // 없는 id 를 지워도 예외를 던지지 않는다 — 목록과 실제가 어긋난
      // 상태에서 사용자가 삭제를 누른 것뿐이다
      Diagnostics.log('sound', '음원 삭제 대상 없음 id=$id');
      return;
    }

    // **행을 먼저 지운다.** 파일만 사라지고 행이 남으면 사용자는 목록에서
    // 보이는데 안 들리는 음원을 보게 된다.
    await (_db.delete(_db.customSounds)..where((t) => t.id.equals(id))).go();

    final file = await CustomSoundFile.resolve(id, row.fileExtension);
    await _deleteFileQuietly(file);

    Diagnostics.log('sound', '음원 삭제 id=$id name=${row.displayName}');
  }

  @override
  Future<String?> resolvePlayablePath(String id) async {
    final row = await _findRow(id);
    if (row == null) return null;

    final file = await CustomSoundFile.resolve(id, row.fileExtension);
    if (!await file.exists()) {
      // 앱 데이터 삭제 등으로 파일만 사라질 수 있다. 호출자는 이걸 받아
      // 기본음으로 떨어진다 — 재생 단계에서 터뜨리지 않는다
      Diagnostics.log('sound', '음원 파일 없음 id=$id name=${row.displayName}');
      return null;
    }
    return file.path;
  }

  Future<CustomSoundRow?> _findRow(String id) {
    final query = _db.select(_db.customSounds)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// 삭제 실패를 삼키되 기록은 남긴다 (CLAUDE.md 규칙 7).
  /// 파일 하나를 못 지운 것이 흐름을 멈출 이유는 없다.
  Future<void> _deleteFileQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      Diagnostics.log('sound', '음원 파일 삭제 실패 path=${file.path} 사유=$error');
    }
  }

  CustomSound _toDomain(CustomSoundRow row) {
    return CustomSound(
      id: row.id,
      displayName: row.displayName,
      fileExtension: row.fileExtension,
      duration: Duration(milliseconds: row.durationMs),
      sizeBytes: row.sizeBytes,
      // Drift 는 DateTime 을 로컬로 되돌려주므로 UTC 로 되돌린다
      createdAt: row.createdAt.toUtc(),
    );
  }

  CustomSoundsCompanion _toRow(CustomSound sound) {
    return CustomSoundsCompanion(
      id: Value(sound.id),
      displayName: Value(sound.displayName),
      fileExtension: Value(sound.fileExtension),
      durationMs: Value(sound.duration.inMilliseconds),
      sizeBytes: Value(sound.sizeBytes),
      createdAt: Value(sound.createdAt.toUtc()),
    );
  }
}
