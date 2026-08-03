import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/geofence_state.dart';
import '../domain/geofence_state_repository.dart';

/// Drift 기반 [GeofenceStateRepository] 구현
///
/// 저장된 상태가 없으면 [GeofenceState.unknown] 을 돌려준다 —
/// 등록 직후의 장소가 여기 해당하며, 첫 판정에서는 알림이 발생하지 않는다
/// (docs/03-DOMAIN.md).
class DriftGeofenceStateRepository implements GeofenceStateRepository {
  DriftGeofenceStateRepository(this._db);

  final AppDatabase _db;

  @override
  Future<GeofenceState> stateOf(String placeId) async {
    final query = _db.select(_db.geofenceStates)
      ..where((t) => t.placeId.equals(placeId));
    final row = await query.getSingleOrNull();
    if (row == null) return GeofenceState.unknown;
    return GeofenceState.values[row.state];
  }

  @override
  Future<Map<String, GeofenceState>> allStates() async {
    final rows = await _db.select(_db.geofenceStates).get();
    return {
      for (final row in rows) row.placeId: GeofenceState.values[row.state],
    };
  }

  @override
  Future<void> updateState(String placeId, GeofenceState state) async {
    await _db
        .into(_db.geofenceStates)
        .insertOnConflictUpdate(
          GeofenceStatesCompanion(
            placeId: Value(placeId),
            state: Value(state.index),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  @override
  Future<void> remove(String placeId) async {
    await (_db.delete(
      _db.geofenceStates,
    )..where((t) => t.placeId.equals(placeId))).go();
  }
}
