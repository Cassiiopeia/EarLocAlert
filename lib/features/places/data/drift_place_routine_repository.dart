import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../domain/place_routine.dart';

/// Drift 기반 [PlaceRoutineRepository] (#315)
class DriftPlaceRoutineRepository implements PlaceRoutineRepository {
  DriftPlaceRoutineRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<PlaceRoutine>> watchAll() {
    final query = _db.select(_db.placeRoutines)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> save(PlaceRoutine routine) async {
    await _db
        .into(_db.placeRoutines)
        .insertOnConflictUpdate(
          PlaceRoutinesCompanion(
            id: Value(routine.id),
            name: Value(routine.name),
            placeIds: Value(jsonEncode(routine.placeIds)),
            isExclusive: Value(routine.isExclusive),
            createdAt: Value(routine.createdAt.toUtc()),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.placeRoutines)..where((t) => t.id.equals(id))).go();
  }

  PlaceRoutine _toDomain(PlaceRoutineRow row) => PlaceRoutine(
    id: row.id,
    name: row.name,
    placeIds: _decodePlaceIds(row.placeIds, routineId: row.id),
    isExclusive: row.isExclusive,
    createdAt: row.createdAt.toUtc(),
  );

  /// 깨진 값은 빈 목록 (루틴 하나 때문에 목록 전체를 못 읽으면 안 됨, 기록은 남김)
  static List<String> _decodePlaceIds(String raw, {required String routineId}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } on Object catch (error) {
      Diagnostics.log(
        'routine',
        'place ids decode failed routine=$routineId error=$error',
      );
    }
    return const [];
  }
}
