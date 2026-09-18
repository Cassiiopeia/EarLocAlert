/// 지도 다크 스타일이 실제로 적용됐는지 지키는 장치 (이슈 #143)
///
/// **주입한 스타일이 조용히 사라지는 일이 있다.** 새로 부팅한 기기에서
/// 홈 지도가 기본(밝은) 스타일로 떴고, 같은 실행 안의 알림 화면 지도는
/// 정상이었다. 로그에는 SDK 경고만 남았다.
///
/// ```
/// InternalStyle with id -1 not found in namespace:
///   [GMM-CLIENT-INJECTED-STYLE-NAMESPACE, 1]
/// ```
///
/// 예외도 없고 앱 로그에도 안 남아, 사용자가 제보해도 추적할 수 없었다.
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../diagnostics/diagnostics.dart';
import '../theme/map_style.dart';

/// 지도가 만들어진 직후 스타일을 **한 번 더 적용하고 결과를 남긴다.**
///
/// 정상일 때는 같은 값을 다시 넣는 것이라 아무 일도 일어나지 않는다.
/// 스타일을 잃은 경우에만 이 호출이 되살린다.
///
/// [where] 는 어느 화면인지다 — 세 화면이 같은 스타일을 쓰는데 한 곳만
/// 실패한 적이 있어, 어디서 났는지 없이는 로그가 쓸모없다.
///
/// **실패해도 던지지 않는다.** 지도 색이 틀린 것보다 화면이 깨지는 쪽이
/// 훨씬 나쁘다.
Future<void> ensureDarkMapStyle(
  GoogleMapController controller,
  String where,
) async {
  try {
    // `GoogleMap.style` 을 쓰라는 안내가 붙어 있지만, **우리는 이미 그것을
    // 쓰고 있고 실패한 것이 바로 그 경로다.** 위젯을 다시 만들지 않고
    // 스타일만 되살릴 수 있는 방법은 이 호출뿐이라 의도적으로 쓴다.
    // ignore: deprecated_member_use
    await controller.setMapStyle(MapStyle.dark);

    // 파싱 오류가 있으면 SDK 가 알려준다. 위 호출이 성공해도 스타일이
    // 거부됐을 수 있으므로 반드시 확인한다.
    final error = await controller.getStyleError();
    if (error != null) {
      Diagnostics.log('map', '지도 스타일 거부됨 화면=$where 사유=$error');
      return;
    }

    Diagnostics.log('map', '지도 스타일 적용 화면=$where');
  } on Object catch (e) {
    // 삼키되 기록은 남긴다 (docs/04-CONVENTIONS.md)
    Diagnostics.log('map', '지도 스타일 적용 실패 화면=$where 사유=$e');
  }
}
