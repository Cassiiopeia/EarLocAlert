import 'package:ear_loc_alert/features/places/presentation/place_map_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 지도가 내 위치에서 시작하는 조건 (이슈 #218)
///
/// 위치 조회는 늦게 끝난다. 그 사이 장소가 불러와져 카메라가 장소에 맞춰졌다면,
/// 늦게 온 내 위치가 그것을 덮어쓰면 안 된다.
void main() {
  test('장소가 없고 카메라를 아직 안 맞췄으면 내 위치에서 시작한다', () {
    expect(
      shouldStartAtCurrentLocation(hasPlaces: false, didFitCamera: false),
      isTrue,
    );
  });

  test('장소가 있으면 장소가 먼저다', () {
    expect(
      shouldStartAtCurrentLocation(hasPlaces: true, didFitCamera: false),
      isFalse,
    );
  });

  test('이미 카메라를 맞췄으면 덮어쓰지 않는다', () {
    expect(
      shouldStartAtCurrentLocation(hasPlaces: false, didFitCamera: true),
      isFalse,
    );
  });
}
