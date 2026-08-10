import '../../core/domain/alert_direction.dart';
import '../../features/geofence/domain/geofence_evaluation.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/geofence/domain/geofence_event_repository.dart';
import '../../features/geofence/domain/geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_target.dart';
import '../../features/places/domain/place_repository.dart';
import 'background_alert_port.dart';
import 'pending_alert.dart';

/// 백그라운드 지오펜스 이벤트 조율 (이슈 #63)
///
/// feature 간 협력은 app 계층이 조율한다 (docs/02-ARCHITECTURE.md 규칙 1) —
/// geofence 판정 결과를 places 정보와 합쳐 알림 여부를 정하는 것이 이
/// 클래스다. 플랫폼 API 를 직접 부르지 않아 전체 흐름이 실기기 없이
/// 테스트된다.
///
/// 백그라운드에서 하는 일은 **판정·저장·알림 발행**이 전부다
/// (docs/02-ARCHITECTURE.md 규칙 5).
class GeofenceBackgroundProcessor {
  GeofenceBackgroundProcessor({
    required PlaceRepository places,
    required GeofenceStateRepository states,
    required GeofenceEventRepository events,
    required GeofenceEvaluator evaluator,
    required BackgroundAlertPort alertPort,
    required String Function() idGenerator,
    required DateTime Function() clock,
  }) : _places = places,
       _states = states,
       _events = events,
       _evaluator = evaluator,
       _alertPort = alertPort,
       _idGenerator = idGenerator,
       _clock = clock;

  final PlaceRepository _places;
  final GeofenceStateRepository _states;
  final GeofenceEventRepository _events;
  final GeofenceEvaluator _evaluator;
  final BackgroundAlertPort _alertPort;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  /// OS 지오펜스 이벤트 하나를 처리한다.
  ///
  /// [latitude]/[longitude] 는 이벤트 시점 기기 좌표 — Android 만 주고
  /// 그마저 null 일 수 있다. 없으면 이력에 장소 중심 좌표를 대신 남긴다.
  Future<void> handle({
    required String placeId,
    required GeofenceEventType eventType,
    double? latitude,
    double? longitude,
  }) async {
    final place = await _places.findById(placeId);
    if (place == null) {
      // 삭제된 장소의 이벤트가 뒤늦게 도착했다 — 상태만 정리하고 끝낸다.
      // OS 등록 해제는 다음 포그라운드 동기화가 처리한다.
      await _states.remove(placeId);
      return;
    }

    final current = await _states.stateOf(placeId);
    final evaluation = _evaluator.evaluateOsTransition(
      current: current,
      eventType: eventType,
    );

    // 상태 저장이 먼저다 — 이후 단계가 실패해도 다음 판정의 기준은 맞아야
    // 하고, 재부팅 후에도 살아 있어야 한다 (docs/03-DOMAIN.md)
    await _states.updateState(placeId, evaluation.state);

    final transition = evaluation.transition;
    if (transition != GeofenceTransition.entered &&
        transition != GeofenceTransition.exited) {
      return;
    }

    final target = GeofenceTarget(
      placeId: place.id,
      latitude: place.latitude,
      longitude: place.longitude,
      radiusMeters: place.radiusMeters,
      direction: place.direction,
      enabled: place.enabled,
      schedules: place.schedules,
    );
    // 같은 시계에서 갈린다 — **이력은 UTC, 스케줄 판정은 로컬.**
    // 스케줄은 "그곳의 아침 8시"라는 벽시계 규칙이라 UTC 로 판정하면
    // 시간대·서머타임에서 어긋난다 (이슈 #81).
    final now = _clock();
    final notify = _evaluator.shouldNotify(
      target: target,
      transition: transition,
      localNow: now.toLocal(),
    );

    final occurredAt = now.toUtc();
    await _events.record(
      GeofenceEvent(
        id: _idGenerator(),
        placeId: place.id,
        type: transition == GeofenceTransition.entered
            ? GeofenceEventType.entered
            : GeofenceEventType.exited,
        occurredAt: occurredAt,
        latitude: latitude ?? place.latitude,
        longitude: longitude ?? place.longitude,
        // OS 이벤트에는 GPS 정확도가 없다. 0(완벽)으로 오독되지 않게
        // -1 을 "정보 없음" 센티널로 쓴다
        accuracyMeters: -1,
        notified: notify,
      ),
    );

    if (!notify) return;

    await _alertPort.notify(
      PendingAlert(
        placeId: place.id,
        placeName: place.name,
        direction: transition == GeofenceTransition.entered
            ? AlertDirection.enter
            : AlertDirection.exit,
        soundEnabled: place.soundEnabled,
        occurredAt: occurredAt,
      ),
    );
  }
}
