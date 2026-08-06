// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/geofence/data/drift_geofence_event_repository.dart';
import '../../features/geofence/data/drift_geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_event_repository.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/geofence/domain/geofence_state_repository.dart';
import '../../features/permission/data/full_screen_intent_channel.dart';
import '../../features/permission/data/permission_handler_service.dart';
import '../../features/permission/data/prefs_reliability_prompt_store.dart';
import '../../features/permission/domain/full_screen_intent_gate.dart';
import '../../features/permission/domain/permission_gate.dart';
import '../../features/permission/domain/permission_service.dart';
import '../../features/permission/domain/reliability_prompt_store.dart';
import '../../features/places/data/drift_place_repository.dart';
import '../../features/places/domain/place_repository.dart';
import '../database/app_database.dart';

part 'providers.g.dart';

/// 의존성 등록 (docs/02-ARCHITECTURE.md)
///
/// DI 는 Riverpod 으로 통일한다 — `get_it` 을 병행하지 않는다.
/// Provider 는 손으로 선언하지 않고 전부 코드 생성이다
/// (docs/04-CONVENTIONS.md).
///
/// 화면은 여기서 **인터페이스 타입**을 받는다. Drift 구현체를 직접
/// 참조하지 않으므로 저장소 교체가 화면 코드를 건드리지 않는다.

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
PlaceRepository placeRepository(Ref ref) {
  return DriftPlaceRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
GeofenceEventRepository geofenceEventRepository(Ref ref) {
  return DriftGeofenceEventRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
GeofenceStateRepository geofenceStateRepository(Ref ref) {
  return DriftGeofenceStateRepository(ref.watch(appDatabaseProvider));
}

/// 전체화면 알림 권한은 `permission_handler` 밖이라 네이티브 채널로 읽는다
/// (이슈 #74). iOS·구버전 Android 에서는 채널이 없어 항상 허용으로 떨어진다.
@Riverpod(keepAlive: true)
FullScreenIntentGate fullScreenIntentGate(Ref ref) =>
    const FullScreenIntentChannel();

@Riverpod(keepAlive: true)
ReliabilityPromptStore reliabilityPromptStore(Ref ref) =>
    const PrefsReliabilityPromptStore();

@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => PermissionHandlerService(
  fullScreenIntent: ref.watch(fullScreenIntentGateProvider),
);

/// 판정 로직은 상태가 없는 순수 객체다
@Riverpod(keepAlive: true)
GeofenceEvaluator geofenceEvaluator(Ref ref) => const GeofenceEvaluator();

@Riverpod(keepAlive: true)
PermissionGate permissionGate(Ref ref) => const PermissionGate();
