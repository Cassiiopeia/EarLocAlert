import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/geofence_event_repository.dart';
import 'drift_geofence_event_repository.dart';

part 'geofence_event_repository_provider.g.dart';

/// 진입·이탈 기록 — 판정기와 보관 기한 정리가 함께 쓴다
@Riverpod(keepAlive: true)
GeofenceEventRepository geofenceEventRepository(Ref ref) {
  return DriftGeofenceEventRepository(ref.watch(appDatabaseProvider));
}
