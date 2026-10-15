import 'package:ear_loc_alert/features/places/presentation/place_map_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지도 위 버튼이 상단 막대를 덮지 않는다 (#280)
void main() {
  // iPhone 16 세로 852, 상단 안전 영역 59
  const screenHeight = 852.0;
  const topSafePadding = 59.0;

  test('처음 높이의 시트에서는 버튼이 보인다', () {
    expect(
      mapControlsReachTopBar(
        screenHeight: screenHeight,
        sheetFraction: 0.34,
        topSafePadding: topSafePadding,
      ),
      isFalse,
    );
  });

  test('시트를 끝까지 올리면 버튼이 상단 막대에 닿아 숨긴다', () {
    expect(
      mapControlsReachTopBar(
        screenHeight: screenHeight,
        sheetFraction: 0.85,
        topSafePadding: topSafePadding,
      ),
      isTrue,
    );
  });
}
