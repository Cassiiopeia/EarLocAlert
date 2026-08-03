import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/geofence_event.dart';
import '../domain/geofence_event_repository.dart';

/// Drift 기반 [GeofenceEventRepository] 구현
class DriftGeofenceEventRepository implements GeofenceEventRepository {
  DriftGeofenceEventRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> record(GeofenceEvent event) async {
    await _db
        .into(_db.geofenceEvents)
        .insertOnConflictUpdate(
          GeofenceEventsCompanion(
            id: Value(event.id),
            placeId: Value(event.placeId),
            type: Value(event.type.index),
            occurredAt: Value(event.occurredAt.toUtc()),
            latitude: Value(event.latitude),
            longitude: Value(event.longitude),
            accuracyMeters: Value(event.accuracyMeters),
            notified: Value(event.notified),
          ),
        );
  }

  @override
  Future<List<GeofenceEvent>> findRecent({int limit = 100}) async {
    final query = _db.select(_db.geofenceEvents)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<GeofenceEvent>> findByPlace(
    String placeId, {
    int limit = 100,
  }) async {
    final query = _db.select(_db.geofenceEvents)
      ..where((t) => t.placeId.equals(placeId))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> deleteOlderThan(DateTime cutoffUtc) async {
    final stmt = _db.delete(_db.geofenceEvents)
      ..where((t) => t.occurredAt.isSmallerThanValue(cutoffUtc.toUtc()));
    return stmt.go();
  }

  GeofenceEvent _toDomain(GeofenceEventRow row) {
    return GeofenceEvent(
      id: row.id,
      placeId: row.placeId,
      type: GeofenceEventType.values[row.type],
      occurredAt: row.occurredAt.toUtc(),
      latitude: row.latitude,
      longitude: row.longitude,
      accuracyMeters: row.accuracyMeters,
      notified: row.notified,
    );
  }
}
