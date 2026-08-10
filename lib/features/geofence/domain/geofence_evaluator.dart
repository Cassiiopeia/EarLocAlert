import '../../../core/domain/alert_schedule.dart';
import 'geofence_event.dart';
import 'geofence_target.dart';
import 'geofence_evaluation.dart';
import 'geofence_state.dart';
import 'position_sample.dart';

/// 지오펜스 진입/이탈 판정 (docs/03-DOMAIN.md)
///
/// 순수 함수다 — 플랫폼·저장소·시계에 의존하지 않는다.
/// 이 클래스가 UI 없이 단위 테스트되는 것이 이 앱 아키텍처의 목적이다
/// (docs/02-ARCHITECTURE.md).
class GeofenceEvaluator {
  const GeofenceEvaluator({
    this.exitMarginRatio = 0.2,
    this.minExitMarginMeters = 20,
  });

  /// 이탈 마진 = max(반경 × ratio, 최소값)
  ///
  /// 반경에 비례하되 하한을 둔다 — 작은 반경에 큰 고정 마진을 쓰면
  /// 이탈이 영영 판정되지 않고, 큰 반경에 작은 마진은 진동을 못 막는다.
  final double exitMarginRatio;
  final double minExitMarginMeters;

  double exitMarginFor(GeofenceTarget target) {
    final proportional = target.radiusMeters * exitMarginRatio;
    return proportional > minExitMarginMeters
        ? proportional
        : minExitMarginMeters;
  }

  /// 측정값 하나로 다음 상태를 판정한다.
  ///
  /// 규칙 (docs/03-DOMAIN.md):
  /// 1. 히스테리시스 — 진입은 `거리 < radius`, 이탈은 `거리 > radius + margin`.
  ///    그 사이 경계 지대에서는 현재 상태를 유지한다.
  /// 2. 정확도가 반경보다 나쁘면 판정을 보류한다 (상태 유지).
  /// 3. `unknown` 에서의 첫 판정은 전이를 만들지 않는다 — 알림 없음.
  /// 4. 같은 상태가 유지되는 동안 전이는 없다 — 알림 중복 차단.
  GeofenceEvaluation evaluate({
    required GeofenceTarget target,
    required GeofenceState current,
    required PositionSample sample,
  }) {
    // 규칙 2 — 정확도 보류. 정확도가 반경보다 크면 이 측정으로는
    // 안팎을 알 수 없다. 지하·실내·터널에서 엉뚱한 알림을 막는다.
    if (sample.accuracyMeters > target.radiusMeters) {
      return GeofenceEvaluation(
        state: current,
        transition: GeofenceTransition.deferred,
      );
    }

    final distance = sample.distanceToMeters(target.latitude, target.longitude);
    final radius = target.radiusMeters.toDouble();
    final exitBoundary = radius + exitMarginFor(target);

    final GeofenceState next;
    if (distance < radius) {
      next = GeofenceState.inside;
    } else if (distance > exitBoundary) {
      next = GeofenceState.outside;
    } else {
      // 규칙 1 — 경계 지대: 상태 유지. 단 unknown 은 유지할 상태가
      // 없으므로 보수적으로 outside 로 본다 (진입 알림은 다음
      // outside → inside 전이에서 정상 발생한다).
      next = current == GeofenceState.unknown ? GeofenceState.outside : current;
    }

    return GeofenceEvaluation(
      state: next,
      transition: _transitionOf(current, next),
    );
  }

  /// OS 지오펜스 이벤트로 다음 상태를 판정한다 (docs/10-DECISIONS.md 014).
  ///
  /// OS 위임 방식에서는 좌표·정확도가 아니라 **전이 자체**가 입력이다.
  /// 규칙 3(unknown 첫 판정 무알림)·규칙 4(같은 상태 반복 무알림)를
  /// 그대로 재사용한다 — 이것이 등록 직후 initialTrigger 와 iOS 재부팅 후
  /// 중복 발화를 별도 코드 없이 걸러낸다.
  GeofenceEvaluation evaluateOsTransition({
    required GeofenceState current,
    required GeofenceEventType eventType,
  }) {
    final next = eventType == GeofenceEventType.entered
        ? GeofenceState.inside
        : GeofenceState.outside;
    return GeofenceEvaluation(
      state: next,
      transition: _transitionOf(current, next),
    );
  }

  GeofenceTransition _transitionOf(GeofenceState from, GeofenceState to) {
    // 규칙 3 — unknown 에서의 첫 확정은 알림을 만들지 않는다
    if (from == GeofenceState.unknown) return GeofenceTransition.none;
    if (from == to) return GeofenceTransition.none;
    return to == GeofenceState.inside
        ? GeofenceTransition.entered
        : GeofenceTransition.exited;
  }

  /// 이 전이가 실제로 알림을 발생시켜야 하는가.
  ///
  /// 전이 판정과 분리한 이유: 전이는 사실이고 알림은 설정이다.
  /// 이력(GeofenceEvent)은 알림 여부와 무관하게 전이를 전부 기록한다.
  ///
  /// [localNow] 는 **로컬 시각**이다 — 스케줄이 벽시계 규칙이라 UTC 를
  /// 넘기면 사용자가 설정한 시각과 어긋난다 (이슈 #81).
  ///
  /// 스케줄을 여기서 거르는 이유는, OS 지오펜스 등록을 해제하는 방식이
  /// 알림을 유실하기 때문이다. 등록에서 빠지면 상태가 `unknown` 으로
  /// 되돌아가고, 창이 열려 재등록되면 `unknown → inside` 가 되어 규칙 3 에
  /// 걸린다. 여기서 거르면 창 밖에서도 상태 추적이 끊기지 않는다.
  bool shouldNotify({
    required GeofenceTarget target,
    required GeofenceTransition transition,
    required DateTime localNow,
  }) {
    if (!target.enabled) return false;
    if (!isScheduleActive(target.schedules, localNow)) return false;
    return switch (transition) {
      GeofenceTransition.entered => target.direction.notifiesOnEnter,
      GeofenceTransition.exited => target.direction.notifiesOnExit,
      GeofenceTransition.none || GeofenceTransition.deferred => false,
    };
  }
}
