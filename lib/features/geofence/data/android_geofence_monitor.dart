import 'package:flutter/services.dart';

import '../domain/geofence_monitor.dart';
import '../domain/geofence_target.dart';
import '../domain/proximity_radius.dart';

/// Android 지오펜스 등록 어댑터 (이슈 #93)
///
/// **왜 native_geofence 를 쓰지 않나** — 그 패키지는 지오펜스 이벤트를
/// WorkManager 로 넘긴다. 즉시 실행 쿼터가 소진되면 일반 작업으로
/// 강등되어 Doze 제한을 받고, 작업 체인이 한 번 실패하면 이후 모든
/// 이벤트가 실행되지 않는다. **앱을 안 쓸수록 알림이 안 오는 구조**라
/// 이 앱의 존재 이유와 정면으로 어긋난다. PendingIntent 목적지가 그
/// 패키지 리시버로 하드코딩돼 있어 가로챌 수도 없다.
///
/// iOS 는 이 경로가 없어(CLLocationManager 직접 사용) native_geofence 를
/// 그대로 쓴다 → [NativeGeofenceMonitor]
///
/// **장소마다 지오펜스를 둘 등록한다** — 실제 반경과 근접 반경.
/// 근접 반경은 정밀 감시를 켜는 트리거이고, 실제 반경은 정밀 감시가
/// 실패했을 때의 폴백이다. 하나만 두면 한쪽이 죽을 때 발화가 통째로
/// 사라진다.
class AndroidGeofenceMonitor implements GeofenceMonitor {
  const AndroidGeofenceMonitor();

  /// 감시 서비스 제어와 같은 채널을 쓴다 — 등록 주체가 서비스이기 때문이다.
  /// 앱이 소유하면 프로세스가 회수될 때 등록도 함께 사라진다.
  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/alert_window',
  );

  @override
  Future<void> sync(List<GeofenceTarget> targets) async {
    await _invoke('syncGeofences', {
      'geofences': [
        for (final t in targets)
          {
            'placeId': t.placeId,
            'latitude': t.latitude,
            'longitude': t.longitude,
            'radiusMeters': t.radiusMeters.toDouble(),
            'proximityRadiusMeters': proximityRadiusMeters(t.radiusMeters),
          },
      ],
    });
  }

  @override
  Future<void> stopAll() => sync(const []);

  @override
  Future<List<String>> registeredPlaceIds() async {
    try {
      final ids = await _channel.invokeListMethod<String>('registeredPlaceIds');
      return ids ?? const [];
    } on Object {
      // 조회 실패는 "등록된 것이 없다"로 본다 — 다음 동기화가 다시 맞춘다
      return const [];
    }
  }

  /// 어떤 호출도 예외를 올리지 않는다.
  ///
  /// 등록 실패는 다음 장소 목록 변경 때 재시도된다
  /// (`GeofenceRegistrationSync._applySafely`).
  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object {
      // 위 주석과 같은 이유
    }
  }
}
