import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/alert_direction.dart';

/// 방향별 기본 마커 색 (hue).
///
/// 기본 마커는 색을 자유롭게 줄 수 없고 hue 만 지정된다. 팔레트의 두 주색에 가장
/// 가까운 값을 쓴다 — 커스텀 아이콘을 그리는 것보다 유지비가 싸고, 방향 구분은
/// 마커 옆 원 색이 함께 해준다. **알림 화면과 지도 홈이 같은 규칙을 쓴다.**
double markerHueFor(AlertDirection direction) =>
    direction == AlertDirection.exit
    ? BitmapDescriptor.hueOrange
    : BitmapDescriptor.hueCyan;
