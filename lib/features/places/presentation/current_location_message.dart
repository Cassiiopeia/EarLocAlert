import '../../../core/l10n/l10n.dart';
import '../data/current_location_channel.dart';

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
