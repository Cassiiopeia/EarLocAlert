/// 위치가 물리적으로 말이 되는가 (이슈 #131)
///
/// **OS 지오펜스는 가끔 크게 튄 좌표를 준다.** WiFi·셀타워 측위가
/// 흔들리면 1km 떨어진 곳에서 진입 이벤트가 오고, 몇 초 뒤 스스로
/// 되돌아간다. 실기기 로그에 그 왕복이 그대로 남았다 — 6초에 약 1km,
/// 시속 600km 였다.
///
/// 정확도로는 막을 수 없다. 튄 좌표의 정확도가 `44m` 로 멀쩡해 보였다 —
/// **문제는 정확도가 아니라 좌표 자체가 순간이동한 것**이다.
library;

import 'dart:math' as math;

import 'position_sample.dart';

/// 사람이 낼 수 있다고 보는 최고 속도.
///
/// KTX 최고 속도(305km/h)를 겨우 넘는 값이다. 실제 이동은 통과하고
/// 측위가 튄 경우만 걸린다. 비행기는 지오펜스가 의미 없는 상황이라
/// 고려하지 않는다.
const double maxPlausibleSpeedKmh = 300;

/// 판정에 필요한 최소 시간 간격.
///
/// 두 측정이 거의 동시에 오면 아주 작은 오차도 무한대에 가까운 속도가
/// 된다. 그 구간은 판정하지 않고 통과시킨다 — **놓치는 쪽이 가짜로
/// 우는 쪽보다 나쁘다.**
const Duration minPlausibilityGap = Duration(seconds: 2);

/// [from] 에서 이 좌표까지 갔다는 것이 말이 되는가.
///
/// 판정할 수 없으면 `true` (통과). 근거 없이 막으면 진짜 도착을 놓친다.
bool isPlausibleMove({
  required PositionSample? from,
  required double latitude,
  required double longitude,
  required DateTime at,
  double? accuracyMeters,
  double maxSpeedKmh = maxPlausibleSpeedKmh,
}) {
  final speed = speedKmhFrom(
    from: from,
    latitude: latitude,
    longitude: longitude,
    at: at,
    accuracyMeters: accuracyMeters,
  );
  return speed == null || speed <= maxSpeedKmh;
}

/// 이동 속도(km/h). 판정할 수 없으면 `null`.
///
/// **두 측정의 정확도만큼은 이동으로 치지 않는다.** GPS 오차 범위 안의
/// 차이를 속도로 계산하면 가만히 있어도 빠르게 움직이는 것으로 잡힌다.
double? speedKmhFrom({
  required PositionSample? from,
  required double latitude,
  required double longitude,
  required DateTime at,
  double? accuracyMeters,
}) {
  if (from == null) return null;

  final elapsed = at.difference(from.timestamp);
  // 시계가 거꾸로 갔거나 두 측정이 거의 동시다 — 판정하지 않는다
  if (elapsed < minPlausibilityGap) return null;

  final gap = from.distanceToMeters(latitude, longitude);
  final tolerance = from.accuracyMeters + (accuracyMeters ?? 0);
  final moved = math.max(0.0, gap - tolerance);

  return moved / elapsed.inMilliseconds * 1000 * 3.6;
}
