import 'package:flutter/services.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/platform/channel_names.dart';

/// 현재 위치 1회 조회 (이슈 #98)
///
/// 지도의 "내 위치" 버튼이 쓴다. 예전에는 좌표를 알아낼 수단이 없어 지도
/// SDK 기본 버튼을 썼는데, 그 버튼은 **우상단 고정이라 상태 알약에 가려**
/// 잘려 보였고 사용자가 존재 자체를 몰랐다.
///
/// **플랫폼 API 를 인터페이스 뒤에 둔다** (docs/02-ARCHITECTURE.md 규칙 3).
/// Android 는 `CurrentLocationProvider.kt`, iOS 는 `AppDelegate.swift` 가 처리한다 (이슈 #213).
abstract interface class CurrentLocationService {
  /// 현재 위치. 권한이 없거나 측정에 실패하면 null.
  Future<({double latitude, double longitude})?> current();
}

class CurrentLocationChannel implements CurrentLocationService {
  const CurrentLocationChannel();

  static const _channel = MethodChannel(ChannelNames.currentLocation);

  @override
  Future<({double latitude, double longitude})?> current() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
      );
      if (result == null) return null;

      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      return (latitude: lat, longitude: lng);
    } on PlatformException catch (e) {
      // 권한 거부·측정 실패·시간 초과 — 정상적으로 일어나는 상태라 예외로 다루지 않되 사유는 남긴다
      Diagnostics.log(
        'location',
        'current location lookup failed reason=${e.code} detail=${e.message}',
      );
      return null;
    } on MissingPluginException {
      // 네이티브 처리기가 없다 — iOS 에서 이게 조용히 삼켜져 권한 문제로 오인됐다 (이슈 #213)
      Diagnostics.log(
        'location',
        'current location lookup failed reason=no_channel',
      );
      return null;
    } on Object catch (e) {
      Diagnostics.log(
        'location',
        'current location lookup failed reason=unexpected error=$e',
      );
      return null;
    }
  }
}

/// 항상 null 을 주는 구현 — 테스트·미지원 플랫폼용
class UnavailableCurrentLocationService implements CurrentLocationService {
  const UnavailableCurrentLocationService();

  @override
  Future<({double latitude, double longitude})?> current() async => null;
}
