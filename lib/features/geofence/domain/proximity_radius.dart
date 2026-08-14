/// 근접 반경 — 정밀 감시를 켤 바깥 경계 (이슈 #93)
///
/// OS 지오펜스는 감지가 수십 초 늦을 수 있다. 실제 반경에서 그것을
/// 기다리면 이미 지나친 뒤다. 그래서 **더 넓은 원을 하나 더 두고**,
/// 거기 들어온 시점부터 앱이 직접 위치를 보며 판정한다.
///
/// 3배로 잡은 이유는 시속 60km(≈17m/s)에서 약 30초의 여유가 나오기
/// 때문이다. 최소 500m 하한을 둔 이유는 작은 반경(50m)에 비례만
/// 적용하면 여유가 150m 밖에 안 되어 전환하자마자 도착해버리기 때문이다.
///
/// 결과는 **언제나 실제 반경보다 크다** — 근접 원이 실제 원을 감싸지
/// 못하면 정밀 감시가 켜지기 전에 도착이 끝난다.
///
/// **미검증 값이다** — 실기기 실측(S-2·S-3) 후 확정한다.
double proximityRadiusMeters(int radiusMeters) {
  const minimumMeters = 500.0;
  const multiplier = 3.0;
  final proportional = radiusMeters * multiplier;
  return proportional > minimumMeters ? proportional : minimumMeters;
}
