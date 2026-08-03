import 'package:native_geofence/native_geofence.dart' as ng;

import '../domain/geofence_monitor.dart';
import '../domain/geofence_target.dart';

/// 백그라운드 이벤트 진입점 시그니처.
///
/// 패키지의 GeofenceCallback typedef 는 공개 API 로 export 되지 않아
/// 같은 시그니처를 직접 선언한다. 함수는 top-level 이어야 한다 —
/// OS 가 isolate 를 새로 띄워 핸들로 찾는다.
typedef GeofenceEventCallback =
    Future<void> Function(ng.GeofenceCallbackParams params);

/// native_geofence 래퍼 (docs/10-DECISIONS.md 014)
///
/// 콜백은 생성자로 주입받는다 — 실제 이벤트 처리(판정·저장·알림)는
/// app 계층의 백그라운드 진입점이 담당하고, data 계층은 feature 밖을
/// 모른다 (docs/02-ARCHITECTURE.md).
class NativeGeofenceMonitor implements GeofenceMonitor {
  NativeGeofenceMonitor({required GeofenceEventCallback callback})
    : _callback = callback;

  final GeofenceEventCallback _callback;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await ng.NativeGeofenceManager.instance.initialize();
    _initialized = true;
  }

  @override
  Future<void> sync(List<GeofenceTarget> targets) async {
    await _ensureInitialized();
    final manager = ng.NativeGeofenceManager.instance;

    final wanted = {for (final t in targets) t.placeId: t};
    final registered = await manager.getRegisteredGeofenceIds();

    // 대상에서 빠진 등록부터 해제한다 — 비활성/삭제된 장소가
    // 계속 발화하는 것이 잘못된 등록보다 나쁘다
    for (final id in registered) {
      if (!wanted.containsKey(id)) {
        await manager.removeGeofenceById(id);
      }
    }

    for (final target in targets) {
      await manager.createGeofence(_toGeofence(target), _callback);
    }
  }

  @override
  Future<void> stopAll() async {
    await _ensureInitialized();
    await ng.NativeGeofenceManager.instance.removeAllGeofences();
  }

  @override
  Future<List<String>> registeredPlaceIds() async {
    await _ensureInitialized();
    return ng.NativeGeofenceManager.instance.getRegisteredGeofenceIds();
  }

  ng.Geofence _toGeofence(GeofenceTarget target) {
    return ng.Geofence(
      id: target.placeId,
      location: ng.Location(
        latitude: target.latitude,
        longitude: target.longitude,
      ),
      radiusMeters: target.radiusMeters.toDouble(),
      // 방향 설정과 무관하게 양쪽을 다 받는다 — 진입 전용이어도
      // 이탈을 알아야 다음 진입을 무장(arm)할 수 있다. 알림 여부는
      // GeofenceEvaluator.shouldNotify 가 방향으로 거른다.
      triggers: const {ng.GeofenceEvent.enter, ng.GeofenceEvent.exit},
      iosSettings: const ng.IosGeofenceSettings(
        // 등록 시점에 이미 반경 안이면 즉시 ENTER 를 받아 상태를
        // 초기화한다. unknown→inside 는 무알림이므로(규칙 3) 오알림이
        // 없고, 이게 없으면 등록 직후의 첫 이탈을 통째로 놓친다.
        initialTrigger: true,
      ),
      androidSettings: const ng.AndroidGeofenceSettings(
        initialTriggers: {ng.GeofenceEvent.enter},
        // 기본 응답성(0) — F2 는 빠른 감지를 요구한다. 배터리 실측 후
        // 필요하면 조정한다 (docs/01-REQUIREMENTS.md 4.1)
      ),
    );
  }
}
