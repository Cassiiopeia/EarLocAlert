import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/full_screen_intent_gate.dart';
import '../domain/permission_kind.dart';
import '../domain/permission_service.dart';
import '../domain/permission_snapshot.dart';

/// `permission_handler` 기반 [PermissionService] 구현
///
/// 플랫폼 차이를 여기서 흡수한다 — 도메인과 화면은 플랫폼을 모른다
/// (docs/05-PLATFORM.md).
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService({
    FullScreenIntentGate fullScreenIntent =
        const AlwaysGrantedFullScreenIntentGate(),
  }) : _fullScreenIntent = fullScreenIntent;

  final FullScreenIntentGate _fullScreenIntent;

  @override
  Future<PermissionSnapshot> check() async {
    return PermissionSnapshot(
      location: _map(await ph.Permission.locationWhenInUse.status),
      backgroundLocation: _map(await ph.Permission.locationAlways.status),
      notification: _map(await ph.Permission.notification.status),
      batteryOptimization: await _batteryOptimizationStatus(),
      overlay: await _overlayStatus(),
      fullScreenIntent: await _fullScreenIntent.status(),
    );
  }

  @override
  Future<PermissionSnapshot> request(PermissionKind kind) async {
    switch (kind) {
      case PermissionKind.location:
        await ph.Permission.locationWhenInUse.request();

      case PermissionKind.backgroundLocation:
        // Android API 30+ 는 앱 내 다이얼로그로 "항상 허용"을 받을 수 없다.
        // request() 를 불러도 거부로 처리되므로 설정 화면으로 보낸다
        // (docs/05-PLATFORM.md).
        if (Platform.isAndroid) {
          await ph.openAppSettings();
        } else {
          await ph.Permission.locationAlways.request();
        }

      case PermissionKind.notification:
        await ph.Permission.notification.request();

      case PermissionKind.batteryOptimization:
        // 시스템 다이얼로그가 바로 뜬다 (매니페스트에
        // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 선언 필요)
        if (Platform.isAndroid) {
          await ph.Permission.ignoreBatteryOptimizations.request();
        }

      case PermissionKind.overlay:
        // "다른 앱 위에 표시" 설정 화면으로 나간다
        if (Platform.isAndroid) {
          await ph.Permission.systemAlertWindow.request();
        }

      case PermissionKind.fullScreenIntent:
        await _fullScreenIntent.openSettings();
    }
    return check();
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  /// iOS 에는 Doze 도 배터리 최적화 목록도 없다 — 막고 있는 것이 없다.
  Future<PermissionStatus> _batteryOptimizationStatus() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    return _map(await ph.Permission.ignoreBatteryOptimizations.status);
  }

  /// iOS 에는 "다른 앱 위에 표시" 개념이 없다.
  Future<PermissionStatus> _overlayStatus() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    return _map(await ph.Permission.systemAlertWindow.status);
  }

  PermissionStatus _map(ph.PermissionStatus status) {
    return switch (status) {
      ph.PermissionStatus.granted ||
      ph.PermissionStatus.limited ||
      ph.PermissionStatus.provisional => PermissionStatus.granted,
      ph.PermissionStatus.denied => PermissionStatus.denied,
      ph.PermissionStatus.permanentlyDenied =>
        PermissionStatus.permanentlyDenied,
      ph.PermissionStatus.restricted => PermissionStatus.restricted,
    };
  }
}
