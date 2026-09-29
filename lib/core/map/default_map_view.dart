import 'dart:ui' show PlatformDispatcher;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 위치를 아직 모를 때 지도가 처음 보여줄 곳 (이슈 #166)
///
/// **서울시청을 모두에게 보이지 않는다.** 예전에는 세 화면에 서울시청이 고정돼
/// 있어서, 위치를 못 얻은 해외 사용자에게도 서울이 떴다. 기기의 지역(국가)으로
/// 가까운 대도시를 고르고, 아는 곳이 없으면 세계 지도를 보여준다.
///
/// 현재 위치로 시작하는 것이 이상적이지만 권한이 아직 없을 수 있고 첫 측정까지
/// 시간이 걸린다 — 회색 화면을 보여주느니 여기서 시작하고 "내 위치"로 옮긴다.
class DefaultMapView {
  const DefaultMapView(this.target, this.zoom, {this.isWorld = false});

  final LatLng target;
  final double zoom;

  /// 특정 도시를 모를 때의 세계 지도. 반경에 맞춘 확대를 하지 않는다
  final bool isWorld;
}

const _world = DefaultMapView(LatLng(20, 0), 2, isWorld: true);

/// 국가 코드(ISO 3166-1 alpha-2)로 고른 시작 화면. 모르면 세계 지도.
DefaultMapView defaultMapViewFor(String? countryCode) =>
    switch (countryCode?.toUpperCase()) {
      'KR' => const DefaultMapView(LatLng(37.5665, 126.9780), 14), // 서울시청
      'JP' => const DefaultMapView(LatLng(35.6812, 139.7671), 14), // 도쿄역
      'CN' => const DefaultMapView(LatLng(39.9042, 116.4074), 13), // 베이징
      'TW' => const DefaultMapView(LatLng(25.0330, 121.5654), 14), // 타이베이
      'HK' => const DefaultMapView(LatLng(22.3193, 114.1694), 13), // 홍콩
      'US' => const DefaultMapView(LatLng(40.7128, -74.0060), 12), // 뉴욕
      'GB' => const DefaultMapView(LatLng(51.5074, -0.1278), 12), // 런던
      _ => _world,
    };

/// 이 기기의 지역으로 정한 시작 화면
DefaultMapView currentDefaultMapView() =>
    defaultMapViewFor(PlatformDispatcher.instance.locale.countryCode);
