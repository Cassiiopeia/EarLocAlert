import 'package:flutter/widgets.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../domain/current_location_service.dart';

/// "내 위치" 실패 안내 문구 (이슈 #227).
///
/// 홈·위치 선택 화면이 같은 문구를 쓴다. 권한 안내는 권한이 원인일 때만 —
/// 시간 초과에 권한 안내를 띄우면 사용자가 멀쩡한 설정을 뒤진다.
String currentLocationFailureMessage(
  AppLocalizations l10n,
  CurrentLocationFailure failure,
) => switch (failure) {
  CurrentLocationFailure.permissionDenied => l10n.placeHomeLocationUnavailable,
  CurrentLocationFailure.measurementFailed => l10n.placeLocationSlow,
};

/// "내 위치" 버튼의 공통 흐름 — 위치를 묻고, 못 얻으면 이유에 맞는 안내를 띄운다 (#278)
///
/// 지도 홈과 위치 선택 화면이 같은 흐름을 두 벌 갖고 있었고, 홈 쪽은 성공해도
/// 기록이 없었다. 카메라를 어디까지 당길지는 화면마다 달라 좌표만 돌려준다.
/// 못 얻었거나 화면이 사라졌으면 null 이다.
Future<({double latitude, double longitude})?> fetchCurrentLocationOrShowReason(
  BuildContext context,
  CurrentLocationService service, {

  /// 로그에 남길 화면 이름 — 어느 화면의 버튼이었는지 가린다
  required String screenName,
}) async {
  final result = await service.current();
  if (!context.mounted) return null;

  final location = result.location;
  if (location == null) {
    final failure = result.failure ?? CurrentLocationFailure.measurementFailed;
    Diagnostics.log(
      'location',
      'my location failed screen=$screenName reason=${failure.name}',
    );
    // 권한 문제인지 측정 지연인지에 따라 안내가 다르다 (이슈 #227)
    context.showToast(currentLocationFailureMessage(context.l10n, failure));
    return null;
  }

  Diagnostics.log(
    'location',
    'my location found screen=$screenName '
        'lat=${location.latitude} lng=${location.longitude}',
  );
  return location;
}
