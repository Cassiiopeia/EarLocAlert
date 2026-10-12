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

/// Android 근접 원에 더하는 여유 (이슈 #260)
///
/// OS 지오펜스 이벤트가 늦게 전달되는 것을 흡수한다. 2026-10-13 소만사
/// 도착 알림이 반경 1150m 장소에서 중심 70m 지점에야 울렸다 — 이벤트가
/// 수 km 늦었다. **추정치다.** 진단 기록의 `[receiver] detail` 줄
/// (`fix_age_s`, `since_last_event_s`)로 실측해 조정한다.
const androidProximityMarginMeters = 2000.0;

/// Android 바깥 원에 더하는 여유 (이슈 #260)
///
/// 이 원 안에 있는 동안 앱이 균형 전력 위치를 직접 확인한다(중간 단계).
/// 근접 원 이벤트가 늦어도 앱이 이미 보고 있게 하려는 것이다.
/// **추정치다** — 1분 주기 측정과 OS 전달 지연을 합쳐 수 분 거리를 덮도록 잡았다.
const androidOuterMarginMeters = 8000.0;

/// Android 근접 원 반경 — [proximityRadiusMeters] 에 여유를 더한다.
///
/// iOS 는 적응형 감시가 상시 위치를 보므로 기존 [proximityRadiusMeters] 를
/// 그대로 쓴다. 배터리를 실측하지 않은 채 바꾸지 않는다.
double androidProximityRadiusMeters(int radiusMeters) =>
    proximityRadiusMeters(radiusMeters) + androidProximityMarginMeters;

/// Android 바깥 원 반경 — 중간 단계 위치 감시를 켜는 경계 (이슈 #260)
///
/// 언제나 [androidProximityRadiusMeters] 보다 크다.
double androidOuterRadiusMeters(int radiusMeters) =>
    proximityRadiusMeters(radiusMeters) + androidOuterMarginMeters;
