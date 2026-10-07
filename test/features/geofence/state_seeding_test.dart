import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/geofence/domain/state_seeding.dart';
import 'package:flutter_test/flutter_test.dart';

/// 등록 순간 상태 초기값 (이슈 #231)
///
/// 틀린 `outside` 는 가짜 도착 알림을, 틀린 `inside` 는 진짜 첫 도착을 삼킨다.
/// 그래서 확실할 때만 정한다 — 이 테스트가 그 경계를 지킨다.
void main() {
  // 반경 300m, 이탈 마진 60m (300×0.2)
  const target = GeofenceTarget(
    placeId: 'a',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 300,
    direction: AlertDirection.enter,
  );

  /// 중심에서 북쪽으로 [meters] 떨어진 측정
  PositionSample fix(double meters, {double accuracy = 20}) => PositionSample(
    latitude: 37.5 + meters / 111195,
    longitude: 127.0,
    accuracyMeters: accuracy,
    timestamp: DateTime.utc(2026, 10, 8),
  );

  test('충분히 밖이면 outside — 이후 진입이 알림이 된다', () {
    final decision = decideSeedState(target: target, fix: fix(1000));

    expect(decision.state, GeofenceState.outside);
    expect(decision.distanceMeters, closeTo(1000, 2));
  });

  test('충분히 안이면 inside — 지금 설계대로 즉시 알림은 없다', () {
    final decision = decideSeedState(target: target, fix: fix(100));

    expect(decision.state, GeofenceState.inside);
  });

  test('정확도가 나쁘면 정하지 않는다', () {
    final decision = decideSeedState(
      target: target,
      fix: fix(5000, accuracy: 500),
    );

    expect(decision.state, isNull);
    expect(decision.skip, SeedSkipReason.poorAccuracy);
  });

  test('정확도를 모르면(-1) 정하지 않는다 — 0(완벽)으로 오독하지 않는다', () {
    final decision = decideSeedState(
      target: target,
      fix: fix(5000, accuracy: -1),
    );

    expect(decision.skip, SeedSkipReason.poorAccuracy);
  });

  test('경계에서 정확도 범위 안이면 정하지 않는다', () {
    // 밖 판정에는 300 + 60 + 20 = 380m 를 넘어야 한다
    expect(
      decideSeedState(target: target, fix: fix(370)).skip,
      SeedSkipReason.nearBoundary,
    );
    // 안 판정에는 300 − 20 = 280m 보다 가까워야 한다
    expect(
      decideSeedState(target: target, fix: fix(290)).skip,
      SeedSkipReason.nearBoundary,
    );
    expect(
      decideSeedState(target: target, fix: fix(390)).state,
      GeofenceState.outside,
    );
    expect(
      decideSeedState(target: target, fix: fix(270)).state,
      GeofenceState.inside,
    );
  });

  test('위치가 없으면 정하지 않는다', () {
    final decision = decideSeedState(target: target, fix: null);

    expect(decision.skip, SeedSkipReason.noFix);
    expect(decision.distanceMeters, isNull);
  });
}
