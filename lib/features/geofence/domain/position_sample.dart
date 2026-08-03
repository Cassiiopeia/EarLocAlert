import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'position_sample.freezed.dart';

/// 위치 측정값 하나 (docs/03-DOMAIN.md)
///
/// geolocator 등 플랫폼 타입에 의존하지 않는다 — domain 은 순수 Dart 다.
/// data 계층이 플랫폼 위치 객체를 이 타입으로 변환해 넘긴다.
@freezed
abstract class PositionSample with _$PositionSample {
  const PositionSample._();

  const factory PositionSample({
    required double latitude,
    required double longitude,

    /// GPS 정확도 (미터). 클수록 부정확하다
    required double accuracyMeters,

    /// UTC
    required DateTime timestamp,
  }) = _PositionSample;

  static const double _earthRadiusMeters = 6371000;

  /// 이 측정점에서 (lat, lng) 까지의 지표면 거리 (haversine)
  double distanceToMeters(double lat, double lng) {
    final dLat = _toRadians(lat - latitude);
    final dLng = _toRadians(lng - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(lat)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
