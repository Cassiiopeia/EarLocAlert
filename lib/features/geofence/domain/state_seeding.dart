import 'geofence_evaluator.dart';
import 'geofence_state.dart';
import 'geofence_target.dart';
import 'position_sample.dart';

/// 상태 초기값을 정하지 못한 이유 (이슈 #231). 로그에 `reason=` 으로 남긴다.
enum SeedSkipReason {
  /// 현재 위치를 얻지 못했다
  noFix('no_fix'),

  /// 측정 정확도가 너무 나쁘다
  poorAccuracy('poor_accuracy'),

  /// 경계에서 정확도 범위 안이라 안팎을 단정할 수 없다
  nearBoundary('near_boundary');

  const SeedSkipReason(this.label);

  final String label;
}

/// 초기값 판단 결과 — [state] 와 [skip] 중 하나만 있다
class SeedDecision {
  const SeedDecision.seeded(GeofenceState this.state, this.distanceMeters)
    : skip = null;

  const SeedDecision.skipped(SeedSkipReason this.skip, [this.distanceMeters])
    : state = null;

  final GeofenceState? state;
  final SeedSkipReason? skip;

  /// 장소 중심까지 거리. 위치가 없으면 null
  final double? distanceMeters;
}

/// 장소를 등록·수정·활성화한 순간 현재 위치로 안팎을 정한다 (이슈 #231).
///
/// **왜 필요한가** — 진입 알림은 `outside → inside` 에서만 난다. 등록 직후
/// 상태는 `unknown` 이고, 그것을 `outside` 로 바꿔 줄 iOS 의 첫 영역 이벤트가
/// 늦거나 유실되면 첫 도착이 `unknown → inside` 가 되어 조용히 지나간다
/// (실기기에서 그랬다). 등록하는 그 순간 사용자는 앱을 보고 있으므로 현재
/// 위치를 얻기 가장 쉬운 때이기도 하다.
///
/// **확실할 때만 정한다.** 틀린 `outside` 는 그 자리에서 가짜 도착 알림을
/// 만들 수 있고(곧 이어 오는 OS 이벤트가 inside 라고 하면), 틀린 `inside` 는
/// 진짜 첫 도착을 삼킨다. 그래서 판정 규칙(히스테리시스)에 정확도만큼의
/// 여유를 더한다:
/// - 밖: 거리 − 정확도 > 반경 + 이탈 마진
/// - 안: 거리 + 정확도 < 반경
/// - 그 사이, 또는 정확도가 [maxAccuracyMeters] 보다 나쁘면 `unknown` 그대로
SeedDecision decideSeedState({
  required GeofenceTarget target,
  required PositionSample? fix,
  GeofenceEvaluator evaluator = const GeofenceEvaluator(),
  double maxAccuracyMeters = 150,
}) {
  if (fix == null) return const SeedDecision.skipped(SeedSkipReason.noFix);

  final distance = fix.distanceToMeters(target.latitude, target.longitude);
  final accuracy = fix.accuracyMeters;
  // 음수 정확도는 "모름"이다 — 0(완벽)으로 오독하면 안 된다
  if (accuracy < 0 || accuracy > maxAccuracyMeters) {
    return SeedDecision.skipped(SeedSkipReason.poorAccuracy, distance);
  }

  final radius = target.radiusMeters.toDouble();
  if (distance - accuracy > radius + evaluator.exitMarginFor(target)) {
    return SeedDecision.seeded(GeofenceState.outside, distance);
  }
  if (distance + accuracy < radius) {
    return SeedDecision.seeded(GeofenceState.inside, distance);
  }
  return SeedDecision.skipped(SeedSkipReason.nearBoundary, distance);
}
