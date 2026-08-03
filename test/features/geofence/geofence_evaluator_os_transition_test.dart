import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluation.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluator.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS 지오펜스 이벤트 판정 (이슈 #63, docs/10-DECISIONS.md 014)
///
/// OS 위임 방식에서는 좌표가 아니라 전이 자체가 입력이다.
/// 기존 규칙 3·4 가 그대로 적용되는지 확인한다.
void main() {
  const evaluator = GeofenceEvaluator();

  group('OS 이벤트 전이 (docs/03-DOMAIN.md 규칙 재사용)', () {
    test('unknown 에서 ENTER — 상태만 잡고 알림 없음 (등록 직후 initialTrigger)', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.unknown,
        eventType: GeofenceEventType.entered,
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('unknown 에서 EXIT — 상태만 잡고 알림 없음', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.unknown,
        eventType: GeofenceEventType.exited,
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('outside 에서 ENTER — 진입 전이', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.outside,
        eventType: GeofenceEventType.entered,
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.entered);
    });

    test('inside 에서 EXIT — 이탈 전이', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.inside,
        eventType: GeofenceEventType.exited,
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.exited);
    });

    test('inside 에서 ENTER 반복 — 무시 (iOS 재부팅 후 중복 발화 억제)', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.inside,
        eventType: GeofenceEventType.entered,
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('outside 에서 EXIT 반복 — 무시', () {
      final result = evaluator.evaluateOsTransition(
        current: GeofenceState.outside,
        eventType: GeofenceEventType.exited,
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.none);
    });
  });
}
