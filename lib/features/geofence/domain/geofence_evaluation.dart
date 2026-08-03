import 'package:freezed_annotation/freezed_annotation.dart';

import 'geofence_state.dart';

part 'geofence_evaluation.freezed.dart';

/// 한 번의 위치 측정에 대한 판정 결과
enum GeofenceTransition {
  /// 상태 변화 없음 — 알림 없음
  none,

  /// outside → inside. 방향 설정에 따라 진입 알림 후보
  entered,

  /// inside → outside. 방향 설정에 따라 이탈 알림 후보
  exited,

  /// 정확도 부족으로 판정 보류 — 상태를 바꾸지 않는다
  deferred,
}

/// 판정 결과: 다음 상태 + 전이 종류 (docs/03-DOMAIN.md)
@freezed
abstract class GeofenceEvaluation with _$GeofenceEvaluation {
  const factory GeofenceEvaluation({
    required GeofenceState state,
    required GeofenceTransition transition,
  }) = _GeofenceEvaluation;
}
