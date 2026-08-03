import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluation.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluator.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = GeofenceEvaluator();

  // 서울시청 부근. 반경 100m
  const target = GeofenceTarget(
    placeId: 'place-1',
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
  );

  /// 대상 중심에서 [meters] 만큼 북쪽으로 떨어진 측정값
  /// (위도 1도 ≈ 111,320m)
  PositionSample sampleAt(double meters, {double accuracy = 10}) {
    return PositionSample(
      latitude: target.latitude + meters / 111320.0,
      longitude: target.longitude,
      accuracyMeters: accuracy,
      timestamp: DateTime.utc(2026, 8, 3, 12),
    );
  }

  group('상태 전이 (docs/03-DOMAIN.md)', () {
    test('unknown → inside 는 알림을 만들지 않는다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.unknown,
        sample: sampleAt(0),
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('unknown → outside 도 알림을 만들지 않는다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.unknown,
        sample: sampleAt(500),
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('outside → inside 는 진입 전이를 만든다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.outside,
        sample: sampleAt(50),
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.entered);
    });

    test('inside → outside 는 이탈 전이를 만든다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.inside,
        sample: sampleAt(500),
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.exited);
    });

    test('같은 상태가 유지되는 동안 전이는 없다 — 알림 중복 차단', () {
      // 반경 안에서 여러 번 측정해도 entered 는 다시 나오지 않는다
      var state = GeofenceState.outside;
      final transitions = <GeofenceTransition>[];

      for (final meters in [50.0, 30.0, 10.0, 60.0]) {
        final result = evaluator.evaluate(
          target: target,
          current: state,
          sample: sampleAt(meters),
        );
        state = result.state;
        transitions.add(result.transition);
      }

      expect(
        transitions.where((t) => t == GeofenceTransition.entered).length,
        1,
        reason: '연속 측정에서 진입 전이는 정확히 한 번이어야 한다',
      );
    });
  });

  group('히스테리시스 (docs/03-DOMAIN.md 규칙 1)', () {
    test('경계 지대에서는 inside 상태가 유지된다', () {
      // 반경 100m + 마진 20m → 100~120m 은 경계 지대
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.inside,
        sample: sampleAt(110),
      );

      expect(result.state, GeofenceState.inside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('경계 지대에서는 outside 상태도 유지된다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.outside,
        sample: sampleAt(110),
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.none);
    });

    test('경계에서 GPS 가 흔들려도 상태가 뒤집히지 않는다 (A-11)', () {
      // 경계(100m) 주변을 오가는 측정 시퀀스 — 마진 안쪽이므로 전이 없음
      var state = GeofenceState.inside;
      for (final meters in [95.0, 108.0, 99.0, 115.0, 102.0]) {
        final result = evaluator.evaluate(
          target: target,
          current: state,
          sample: sampleAt(meters),
        );
        state = result.state;
        expect(
          result.transition,
          GeofenceTransition.none,
          reason: '$meters m 지점에서 전이가 발생하면 안 된다',
        );
      }
    });

    test('이탈 마진은 반경에 비례하되 하한을 갖는다', () {
      expect(evaluator.exitMarginFor(target), 20); // max(100*0.2, 20)

      const bigTarget = GeofenceTarget(
        placeId: 'p',
        latitude: 0,
        longitude: 0,
        radiusMeters: 1000,
        direction: AlertDirection.enter,
      );
      expect(evaluator.exitMarginFor(bigTarget), 200); // 1000*0.2

      const smallTarget = GeofenceTarget(
        placeId: 'p',
        latitude: 0,
        longitude: 0,
        radiusMeters: 50,
        direction: AlertDirection.enter,
      );
      expect(evaluator.exitMarginFor(smallTarget), 20); // 하한
    });
  });

  group('정확도 보류 (docs/03-DOMAIN.md 규칙 2)', () {
    test('정확도가 반경보다 나쁘면 판정을 보류하고 상태를 바꾸지 않는다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.outside,
        sample: sampleAt(0, accuracy: 150), // 중심 위지만 정확도 150m
      );

      expect(result.state, GeofenceState.outside);
      expect(result.transition, GeofenceTransition.deferred);
    });

    test('보류는 unknown 상태도 유지한다', () {
      final result = evaluator.evaluate(
        target: target,
        current: GeofenceState.unknown,
        sample: sampleAt(0, accuracy: 500),
      );

      expect(result.state, GeofenceState.unknown);
      expect(result.transition, GeofenceTransition.deferred);
    });
  });

  group('알림 여부 판정 (shouldNotify)', () {
    test('진입 전이 + enter/both 방향이면 알림', () {
      expect(
        evaluator.shouldNotify(
          target: target, // both
          transition: GeofenceTransition.entered,
        ),
        isTrue,
      );
    });

    test('진입 전이라도 exit 전용이면 알림 없음', () {
      const exitOnly = GeofenceTarget(
        placeId: 'p',
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        direction: AlertDirection.exit,
      );
      expect(
        evaluator.shouldNotify(
          target: exitOnly,
          transition: GeofenceTransition.entered,
        ),
        isFalse,
      );
    });

    test('비활성(enabled=false) 장소는 어떤 전이에도 알림 없음 (F1.7)', () {
      const disabled = GeofenceTarget(
        placeId: 'p',
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        direction: AlertDirection.both,
        enabled: false,
      );
      expect(
        evaluator.shouldNotify(
          target: disabled,
          transition: GeofenceTransition.entered,
        ),
        isFalse,
      );
      expect(
        evaluator.shouldNotify(
          target: disabled,
          transition: GeofenceTransition.exited,
        ),
        isFalse,
      );
    });

    test('none/deferred 전이는 알림 없음', () {
      expect(
        evaluator.shouldNotify(
          target: target,
          transition: GeofenceTransition.none,
        ),
        isFalse,
      );
      expect(
        evaluator.shouldNotify(
          target: target,
          transition: GeofenceTransition.deferred,
        ),
        isFalse,
      );
    });
  });
}
