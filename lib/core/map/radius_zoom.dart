/// 반경에 맞는 지도 줌 단계 (이슈 #142)
///
/// 반경 50m 를 세계 지도에서 찍게 하면 아무도 못 찍는다. 반대로 1km 반경을
/// 바짝 당겨 보여주면 원이 화면을 넘어가 어디인지 알 수 없다.
///
/// **세 화면이 같은 표를 쓴다** — 장소 선택·지도 홈·알림 화면. 예전에는
/// 화면마다 같은 표를 복사해 두었는데, 한쪽만 고치면 조용히 어긋난다.
library;

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
