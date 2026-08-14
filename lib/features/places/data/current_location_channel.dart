import 'package:flutter/services.dart';

/// 현재 위치 1회 조회 (이슈 #98)
///
/// 지도의 "내 위치" 버튼이 쓴다. 예전에는 좌표를 알아낼 수단이 없어 지도
/// SDK 기본 버튼을 썼는데, 그 버튼은 **우상단 고정이라 상태 알약에 가려**
/// 잘려 보였고 사용자가 존재 자체를 몰랐다.
///
/// **플랫폼 API 를 인터페이스 뒤에 둔다** (docs/02-ARCHITECTURE.md 규칙 3).
/// iOS 에는 채널이 없어 조용히 null 이 되고, 화면은 SDK 버튼으로 물러난다.
abstract interface class CurrentLocationService {
  /// 현재 위치. 권한이 없거나 측정에 실패하면 null.
  Future<({double latitude, double longitude})?> current();
}

class CurrentLocationChannel implements CurrentLocationService {
  const CurrentLocationChannel();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/current_location',
  );

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
    } on Object {
      // 채널이 없는 플랫폼(iOS)·권한 거부·측정 실패 전부 여기로 온다.
      // 위치를 못 얻는 것은 정상적으로 일어나는 상태다 — 예외로 다루지 않는다.
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
