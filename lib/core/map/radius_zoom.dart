/// 반경에 맞는 지도 줌 단계 (이슈 #142)
///
/// 반경 50m 를 세계 지도에서 찍게 하면 아무도 못 찍는다. 반대로 1km 반경을
/// 바짝 당겨 보여주면 원이 화면을 넘어가 어디인지 알 수 없다.
///
/// **세 화면이 같은 표를 쓴다** — 장소 선택·지도 홈·알림 화면. 예전에는
/// 화면마다 같은 표를 복사해 두었는데, 한쪽만 고치면 조용히 어긋난다.
library;

import 'dart:math' as math;

/// 반경이 화면을 적당히 채우는 줌 단계.
///
/// 기준은 **장소를 고르는 화면**이다 — 핀을 정확히 찍어야 하므로 가장
/// 바짝 당긴다. 더 넓게 보여줘야 하는 화면은 [wider] 로 단계를 낮춘다.
double zoomForRadius(double meters) {
  if (meters <= 100) return 17;
  if (meters <= 300) return 16;
  if (meters <= 800) return 15;
  return 14;
}

/// [zoomForRadius] 보다 [steps] 단계 넓게.
///
/// 지도 홈처럼 **장소가 어디쯤인지**를 보여주는 화면용이다. 한 단계가
/// 대략 두 배 넓이다.
double zoomForRadiusWider(double meters, {double steps = 1}) =>
    zoomForRadius(meters) - steps;

/// 원 지름이 지도 폭의 [fill] 만큼 차는 줌 (이슈 #152 QA).
///
/// 지도 선택 화면용이다. 단계 표([zoomForRadius])는 800m 를 넘으면 전부
/// 14 라, 반경 2000m 원의 지름이 화면 폭의 1.3배가 되어 양옆이 잘렸다.
/// 반경을 고르는 화면에서 원이 잘리면 무엇을 고르는지 볼 수 없다.
///
/// 위도를 넣는 이유 — 같은 줌이라도 1dp 가 덮는 거리는 위도가 높을수록
/// 짧다 (메르카토르). 서울과 제주만 해도 달라진다.
double zoomToFitRadius({
  required double radiusMeters,
  required double latitude,
  required double widthDp,
  double fill = 0.7,
}) {
  // 줌 0 에서 적도의 1dp 가 덮는 거리 (256dp 타일 기준)
  const metersPerDpAtZoom0 = 156543.03392;
  final perDpAtZoom0 = metersPerDpAtZoom0 * math.cos(latitude * math.pi / 180);
  final wanted = (2 * radiusMeters) / (fill * widthDp);
  final zoom = math.log(perDpAtZoom0 / wanted) / math.ln2;
  return zoom.clamp(3.0, 20.0);
}
