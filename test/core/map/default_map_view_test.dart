import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/map/default_map_view.dart';

/// 지도 시작 화면 (이슈 #166) — 서울시청을 모두에게 보이지 않는다
void main() {
  test('한국 기기는 서울에서 시작한다', () {
    final view = defaultMapViewFor('KR');
    expect(view.target.latitude, closeTo(37.5665, 1e-4));
    expect(view.isWorld, isFalse);
  });

  test('일본, 중국, 미국 기기는 자기 지역 대도시에서 시작한다', () {
    expect(defaultMapViewFor('JP').target.longitude, closeTo(139.7671, 1e-3));
    expect(defaultMapViewFor('CN').target.longitude, closeTo(116.4074, 1e-3));
    expect(defaultMapViewFor('US').target.longitude, closeTo(-74.0060, 1e-3));
  });

  test('대소문자를 가리지 않는다', () {
    expect(defaultMapViewFor('kr').target.latitude, closeTo(37.5665, 1e-4));
  });

  test('모르는 지역은 서울이 아니라 세계 지도다', () {
    for (final code in [null, '', 'FR', 'BR', 'ZZ']) {
      final view = defaultMapViewFor(code);
      expect(view.isWorld, isTrue, reason: '$code');
      expect(view.zoom, lessThan(5), reason: '도시를 모르면 멀리서 보인다');
      expect(
        (view.target.latitude - 37.5665).abs() > 1,
        isTrue,
        reason: '$code 에게 서울시청을 보이지 않는다',
      );
    }
  });
}
