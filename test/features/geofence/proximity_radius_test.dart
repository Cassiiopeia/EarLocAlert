import 'package:ear_loc_alert/features/geofence/domain/proximity_radius.dart';
import 'package:flutter_test/flutter_test.dart';

/// 근접 반경 — 정밀 감시로 전환할 바깥 경계 (이슈 #93)
void main() {
  test('작은 반경은 최소값 500m 로 올라간다', () {
    // 100 × 3 = 300 < 500
    expect(proximityRadiusMeters(100), 500);
  });

  test('큰 반경은 3배가 최소값을 넘어 비례한다', () {
    // 500 × 3 = 1500 > 500
    expect(proximityRadiusMeters(500), 1500);
  });

  test('경계값 — 3배가 정확히 최소값이면 최소값이다', () {
    // 166 × 3 = 498 < 500 → 하한
    expect(proximityRadiusMeters(500 ~/ 3), 500);
  });

  test('최소 반경 50m 도 하한이 적용된다', () {
    expect(proximityRadiusMeters(50), 500);
  });

  test('최대 반경 2000m 도 계산된다', () {
    expect(proximityRadiusMeters(2000), 6000);
  });

  test('언제나 실제 반경보다 크다 — 폴백 지오펜스를 감싸야 한다', () {
    for (final radius in [50, 100, 166, 167, 200, 500, 1000, 2000]) {
      expect(
        proximityRadiusMeters(radius),
        greaterThan(radius.toDouble()),
        reason: '반경 $radius 에서 근접 원이 실제 원을 감싸지 못한다',
      );
    }
  });
}
