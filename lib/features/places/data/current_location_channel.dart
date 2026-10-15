import 'package:flutter/services.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/platform/channel_names.dart';
import '../domain/current_location_service.dart';

export '../domain/current_location_service.dart';

/// 네이티브 실패 코드를 실패 이유로 옮긴다.
///
/// 계약된 코드: `permission_denied` · `timeout` · `location_failed` · `no_location`.
/// 모르는 코드는 측정 실패로 본다 — 권한 안내는 권한이 원인일 때만 띄운다.
CurrentLocationFailure failureFromCode(String code) => switch (code) {
  'permission_denied' => CurrentLocationFailure.permissionDenied,
  _ => CurrentLocationFailure.measurementFailed,
};

class CurrentLocationChannel implements CurrentLocationService {
  const CurrentLocationChannel();

  static const _channel = MethodChannel(ChannelNames.currentLocation);

  @override
  Future<CurrentLocationResult> current() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
      );
      if (result == null) {
        // Android 는 권한 없음·측정 실패를 모두 null 로 돌려줘 구분이 안 된다.
        // 예전 안내(권한 확인)를 유지한다 — iOS 는 사유 코드로 온다
        Diagnostics.log(
          'location',
          'current location lookup failed reason=null_result',
        );
        return const CurrentLocationResult.failed(
          CurrentLocationFailure.permissionDenied,
        );
      }

      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        Diagnostics.log(
          'location',
          'current location lookup failed reason=malformed_result',
        );
        return const CurrentLocationResult.failed(
          CurrentLocationFailure.measurementFailed,
        );
      }

      return CurrentLocationResult.found((
        latitude: lat,
        longitude: lng,
      ), accuracyMeters: (result['accuracy'] as num?)?.toDouble());
    } on PlatformException catch (e) {
      // 권한 거부·측정 실패·시간 초과 — 정상적으로 일어나는 상태라 예외로 다루지 않되 사유는 남긴다
      Diagnostics.log(
        'location',
        'current location lookup failed reason=${e.code} detail=${e.message}',
      );
      return CurrentLocationResult.failed(failureFromCode(e.code));
    } on MissingPluginException {
      // 네이티브 처리기가 없다 — iOS 에서 이게 조용히 삼켜져 권한 문제로 오인됐다 (이슈 #213)
      Diagnostics.log(
        'location',
        'current location lookup failed reason=no_channel',
      );
      return const CurrentLocationResult.failed(
        CurrentLocationFailure.measurementFailed,
      );
    } on Object catch (e) {
      Diagnostics.log(
        'location',
        'current location lookup failed reason=unexpected error=$e',
      );
      return const CurrentLocationResult.failed(
        CurrentLocationFailure.measurementFailed,
      );
    }
  }
}

/// 항상 실패하는 구현 — 테스트·미지원 플랫폼용
class UnavailableCurrentLocationService implements CurrentLocationService {
  const UnavailableCurrentLocationService({
    this.failure = CurrentLocationFailure.permissionDenied,
  });

  /// 돌려줄 실패 이유. 테스트가 안내 문구 분기를 확인할 때 바꾼다
  final CurrentLocationFailure failure;

  @override
  Future<CurrentLocationResult> current() async =>
      CurrentLocationResult.failed(failure);
}
