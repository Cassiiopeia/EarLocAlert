import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/geofence_state_repository.dart';
import 'drift_geofence_state_repository.dart';

part 'geofence_state_repository_provider.g.dart';

/// 장소별 안/밖 상태 — 재부팅 뒤에도 살아 있어야 해서 Drift 에 둔다
@Riverpod(keepAlive: true)
GeofenceStateRepository geofenceStateRepository(Ref ref) {
  return DriftGeofenceStateRepository(ref.watch(appDatabaseProvider));
}
