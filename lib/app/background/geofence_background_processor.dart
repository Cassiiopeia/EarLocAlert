import '../../core/diagnostics/diagnostics.dart';
import '../../core/domain/alert_direction.dart';
import '../../core/domain/alert_schedule.dart';
import '../../features/geofence/domain/alert_suppression.dart';
import '../../features/geofence/domain/geofence_evaluation.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/geofence/domain/geofence_event_repository.dart';
import '../../features/geofence/domain/geofence_state.dart';
import '../../features/geofence/domain/geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_target.dart';
import '../../features/geofence/domain/position_sample.dart';
import '../../features/places/domain/alert_place.dart';
import '../../features/places/domain/place_repository.dart';
import 'background_alert_port.dart';
import 'pending_alert.dart';

/// 백그라운드 지오펜스 이벤트 조율 (이슈 #63, #93)
///
/// feature 간 협력은 app 계층이 조율한다 (docs/02-ARCHITECTURE.md 규칙 1) —
/// geofence 판정 결과를 places 정보와 합쳐 알림 여부를 정하는 것이 이
/// 클래스다. 플랫폼 API 를 직접 부르지 않아 전체 흐름이 실기기 없이
/// 테스트된다.
///
/// **진입점이 셋이고 그 뒤는 하나다** (이슈 #93):
///
/// | 진입점 | 입력 | 알림 발행 | 쓰는 곳 |
/// |---|---|---|---|
/// | [handle] | OS 전이 | 한다 | 기존 백그라운드 콜백 (iOS) |
/// | [handleTransition] | OS 전이 | 안 한다 | 감시 서비스 폴백 경로 |
/// | [handlePosition] | 좌표 측정 | 안 한다 | 감시 서비스 정밀 모드 |
///
/// 판정 이후(상태 저장·이력 기록·`shouldNotify`)는 [_recordAndDecide] 하나로
/// 모인다. 이 부분을 복제하면 경로마다 규칙이 어긋나 한쪽에서만 울리거나
/// 두 번 울린다.
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

  /// OS 지오펜스 이벤트 하나를 처리하고 **알림까지 발행한다.**
  ///
  /// [latitude]/[longitude] 는 이벤트 시점 기기 좌표 — Android 만 주고
  /// 그마저 null 일 수 있다. 없으면 이력에 장소 중심 좌표를 대신 남긴다.
  Future<void> handle({
    required String placeId,
    required GeofenceEventType eventType,
    double? latitude,
    double? longitude,
  }) async {
    final alert = await handleTransition(
      placeId: placeId,
      eventType: eventType,
      latitude: latitude,
      longitude: longitude,
    );
    if (alert == null) return;
    await _alertPort.notify(alert);
  }

  /// OS 지오펜스 전이를 판정하고 알림 후보를 돌려준다 (이슈 #93).
  ///
  /// [handle] 과 달리 **알림을 발행하지 않는다** — 발행 주체가 네이티브
  /// 감시 서비스이기 때문이다. 판정 규칙은 완전히 같다.
  Future<PendingAlert?> handleTransition({
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
      Diagnostics.log(
        'engine',
        '판정 place=$placeId → 알림없음 '
            '(사유=${AlertSuppression.placeNotFound.label})',
      );
      return null;
    }

    final current = await _states.stateOf(placeId);
    final evaluation = _evaluator.evaluateOsTransition(
      current: current,
      eventType: eventType,
    );

    // 상태 저장이 먼저다 — 이후 단계가 실패해도 다음 판정의 기준은 맞아야
    // 하고, 재부팅 후에도 살아 있어야 한다 (docs/03-DOMAIN.md)
    await _states.updateState(placeId, evaluation.state);
    _logTransitionIfChanged(
      place: place,
      from: current,
      to: evaluation.state,
      latitude: latitude,
      longitude: longitude,
    );

    return _recordAndDecide(
      place: place,
      target: _targetOf(place),
      transition: evaluation.transition,
      latitude: latitude,
      longitude: longitude,
      // OS 이벤트는 드물게 온다 — 변화가 없어도 남길 값어치가 있다
      logQuietDecision: true,
    );
  }

  /// 정밀 측정 하나로 모든 활성 장소를 판정한다 (이슈 #93).
  ///
  /// OS 전이 판정과 달리 **좌표가 입력이다.** 근접 반경 안에서 감시
  /// 서비스가 위치를 직접 받을 때 쓴다.
  ///
  /// 여러 장소가 동시에 전이할 수 있지만 **알림은 하나만 돌려준다** —
  /// 진동과 화면은 하나뿐이다. 나머지 장소의 상태·이력은 정상 기록된다.
  /// 먼저 발견된 것을 쓰는 이유는 목록 순서가 생성 시각 오름차순이라
  /// 결정적이기 때문이다.
  Future<PendingAlert?> handlePosition({required PositionSample sample}) async {
    final places = await _places.findAll();
    PendingAlert? firstAlert;
    var inspected = 0;

    for (final place in places) {
      // 비활성 장소는 상태도 건드리지 않는다 — 다시 켤 때 묵은 상태와
      // initialTrigger 가 만나 가짜 알림이 터지는 것을 막는다
      if (!place.enabled) continue;
      inspected++;

      final target = _targetOf(place);
      final current = await _states.stateOf(place.id);
      final evaluation = _evaluator.evaluate(
        target: target,
        current: current,
        sample: sample,
      );

      await _states.updateState(place.id, evaluation.state);
      _logTransitionIfChanged(
        place: place,
        from: current,
        to: evaluation.state,
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracyMeters: sample.accuracyMeters,
      );

      final alert = await _recordAndDecide(
        place: place,
        target: target,
        transition: evaluation.transition,
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracyMeters: sample.accuracyMeters,
        // **정밀 측정은 몇 초마다 온다.** 장소마다 "전이없음"을 남기면
        // 그것만으로 로그가 가득 차 정작 필요한 기록을 밀어낸다.
        // 변화가 없는 판정은 호출부가 한 줄로 요약한다 (이슈 #127).
        logQuietDecision: false,
      );
      firstAlert ??= alert;
    }

    // **두 줄을 한 줄로 합친다** (이슈 #127). 예전에는 좌표(`위치 측정`)와
    // 결과(`판정 결과 알림 없음`)가 따로 나와, 정보는 적은데 자리는 두 배로
    // 먹었다. 알림이 났으면 그쪽 로그가 상세하므로 여기서는 생략한다.
    if (firstAlert == null) {
      Diagnostics.log(
        'engine',
        '정밀 판정 lat=${sample.latitude} lng=${sample.longitude} '
            'acc=${sample.accuracyMeters.toStringAsFixed(0)}m '
            '→ 알림없음 (검토 $inspected곳)',
      );
    }

    return firstAlert;
  }

  /// 전이를 이력에 남기고 알림이 필요한지 판단한다.
  ///
  /// **세 진입점이 공유한다** — 여기를 복제하면 OS 경로와 정밀 경로의
  /// 규칙이 반드시 어긋난다.
  ///
  /// [accuracyMeters] 가 null 이면 OS 이벤트다. GPS 정확도가 없으므로
  /// 0(완벽)으로 오독되지 않게 -1 을 "정보 없음" 센티널로 쓴다.
  Future<PendingAlert?> _recordAndDecide({
    required AlertPlace place,
    required GeofenceTarget target,
    required GeofenceTransition transition,
    double? latitude,
    double? longitude,
    double? accuracyMeters,

    /// 변화 없는 판정도 남길 것인가 (이슈 #127).
    ///
    /// OS 이벤트는 드물어서 남길 값어치가 있지만, 정밀 측정은 몇 초마다
    /// 오므로 "전이없음"까지 남기면 로그가 그것만으로 가득 찬다.
    required bool logQuietDecision,
  }) async {
    // 같은 시계에서 갈린다 — **이력은 UTC, 스케줄 판정은 로컬.**
    // 스케줄은 "그곳의 아침 8시"라는 벽시계 규칙이라 UTC 로 판정하면
    // 시간대·서머타임에서 어긋난다 (이슈 #81).
    final now = _clock();

    // **왜 안 울렸는지가 이 앱에서 가장 자주 묻는 질문이다** (이슈 #127).
    // 여섯 가지 사유를 갈라 남긴다 — 특히 정확도 부족(deferred)은
    // "움직이지 않아서"와 구분되어야 한다.
    final suppression = suppressionOf(
      target: target,
      transition: transition,
      scheduleActive: isScheduleActive(target.schedules, now.toLocal()),
    );

    if (logQuietDecision || suppression != AlertSuppression.noTransition) {
      Diagnostics.log(
        'engine',
        formatDecision(
          placeId: place.id,
          placeName: place.name,
          transition: transition,
          suppression: suppression,
          direction: place.direction,
          accuracyMeters: accuracyMeters,
        ),
      );
    }

    if (transition != GeofenceTransition.entered &&
        transition != GeofenceTransition.exited) {
      return null;
    }

    final notify = suppression == null;
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
        accuracyMeters: accuracyMeters ?? -1,
        notified: notify,
      ),
    );

    if (!notify) return null;

    return PendingAlert(
      placeId: place.id,
      placeName: place.name,
      direction: transition == GeofenceTransition.entered
          ? AlertDirection.enter
          : AlertDirection.exit,
      soundEnabled: place.soundEnabled,
      occurredAt: occurredAt,
      sound: place.sound,
    );
  }

  /// 상태가 실제로 바뀐 경우에만 남긴다 (이슈 #127).
  ///
  /// **전이는 사실이고 알림은 설정이다** (docs/03-DOMAIN.md). 알림이
  /// 안 나가도 전이는 일어났을 수 있으므로 판정과 따로 기록한다 —
  /// "반경에 들어온 것은 맞는데 왜 조용했나"를 가르는 단서다.
  void _logTransitionIfChanged({
    required AlertPlace place,
    required GeofenceState from,
    required GeofenceState to,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    if (from == to) return;
    Diagnostics.log(
      'geofence',
      formatTransition(
        placeId: place.id,
        placeName: place.name,
        from: from,
        to: to,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
      ),
    );
  }

  /// AlertPlace → GeofenceTarget 매핑 (docs/02-ARCHITECTURE.md 규칙 1)
  ///
  /// geofence 는 places 를 모른다. 판정에 필요한 값만 옮긴다.
  GeofenceTarget _targetOf(AlertPlace place) => GeofenceTarget(
    placeId: place.id,
    latitude: place.latitude,
    longitude: place.longitude,
    radiusMeters: place.radiusMeters,
    direction: place.direction,
    enabled: place.enabled,
    // OS 등록 여부는 스케줄과 무관하다 — 창 밖에도 등록을 유지해야
    // 상태 추적이 끊기지 않는다 (이슈 #81). 값만 실어 보낸다.
    schedules: place.schedules,
  );
}
