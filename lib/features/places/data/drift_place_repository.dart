import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/alert_direction.dart';
import '../domain/alert_place.dart';
import '../domain/place_repository.dart';

/// Drift 기반 [PlaceRepository] 구현 (docs/02-ARCHITECTURE.md)
///
/// Drift 예외를 그대로 위로 올리지 않는다 — 화면이 `DriftRemoteException` 을
/// 아는 순간 저장소 교체가 불가능해진다 (docs/04-CONVENTIONS.md).
class DriftPlaceRepository implements PlaceRepository {
  DriftPlaceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<AlertPlace>> findAll() async {
    final query = _db.select(_db.alertPlaces)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<AlertPlace>> findEnabled() async {
    final query = _db.select(_db.alertPlaces)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<AlertPlace?> findById(String id) async {
    final query = _db.select(_db.alertPlaces)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(AlertPlace place) async {
    await _db.into(_db.alertPlaces).insertOnConflictUpdate(_toRow(place));
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.alertPlaces)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {
    await (_db.update(_db.alertPlaces)..where((t) => t.id.equals(id))).write(
      AlertPlacesCompanion(enabled: Value(enabled)),
    );
  }

  @override
  Future<int> count() async {
    final countExp = _db.alertPlaces.id.count();
    final query = _db.selectOnly(_db.alertPlaces)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Stream<List<AlertPlace>> watchAll() {
    final query = _db.select(_db.alertPlaces)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  AlertPlace _toDomain(AlertPlaceRow row) {
    return AlertPlace(
      id: row.id,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      radiusMeters: row.radiusMeters,
      direction: AlertDirection.values[row.direction],
      enabled: row.enabled,
      soundEnabled: row.soundEnabled,
      schedules: row.schedules,
      // Drift 는 DateTime 을 로컬로 되돌려주므로 UTC 로 되돌린다
      // (docs/04-CONVENTIONS.md — 저장은 UTC, 표시 직전에만 로컬)
      createdAt: row.createdAt.toUtc(),
    );
  }

  AlertPlacesCompanion _toRow(AlertPlace place) {
    return AlertPlacesCompanion(
      id: Value(place.id),
      name: Value(place.name),
      latitude: Value(place.latitude),
      longitude: Value(place.longitude),
      radiusMeters: Value(place.radiusMeters),
      direction: Value(place.direction.index),
      enabled: Value(place.enabled),
      soundEnabled: Value(place.soundEnabled),
      schedules: Value(place.schedules),
      createdAt: Value(place.createdAt.toUtc()),
    );
  }
}
