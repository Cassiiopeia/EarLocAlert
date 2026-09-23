import 'dart:math' as math;

import 'package:ear_loc_alert/core/map/radius_zoom.dart';
import 'package:flutter_test/flutter_test.dart';

/// 반경 ↔ 지도 줌 (이슈 #142 · #152 QA)
void main() {
  group('zoomToFitRadius — 지도 선택 화면에서 원이 잘리지 않는가', () {
    /// 그 줌에서 원 지름이 화면 폭의 몇 배인지
    double diameterRatio(double radius, double lat, double width) {
      final zoom = zoomToFitRadius(
        radiusMeters: radius,
        latitude: lat,
        widthDp: width,
      );
      final metersPerDp =
          156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
      return (2 * radius / metersPerDp) / width;
    }

    test('어떤 반경이든 원 지름이 화면 폭의 70% 다', () {
      // 단계 표로는 2000m 가 폭의 1.3배라 양옆이 잘렸다
      for (final radius in [50.0, 100.0, 300.0, 800.0, 2000.0]) {
        expect(diameterRatio(radius, 37.5665, 411), closeTo(0.7, 0.001));
      }
    });

    test('위도가 높으면 같은 반경을 덜 당겨 담는다 — 1dp 가 덮는 거리가 짧다', () {
      final seoul = zoomToFitRadius(
        radiusMeters: 500,
        latitude: 37.5,
        widthDp: 411,
      );
      final equator = zoomToFitRadius(
        radiusMeters: 500,
        latitude: 0,
        widthDp: 411,
      );
      // 메르카토르: 위도가 높을수록 같은 줌의 1dp 가 짧은 거리를 덮는다
      expect(seoul, lessThan(equator));
    });

    test('줌은 지도가 지원하는 범위 안이다', () {
      expect(
        zoomToFitRadius(radiusMeters: 0.1, latitude: 37.5, widthDp: 411),
        lessThanOrEqualTo(20),
      );
    });
  });

  test('단계 표 — 반경이 클수록 멀리서 본다', () {
    expect(zoomForRadius(50), greaterThan(zoomForRadius(2000)));
    expect(zoomForRadiusWider(100), zoomForRadius(100) - 1);
  });
}
