import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/permission_kind.dart';
import '../domain/permission_service.dart';
import '../domain/permission_snapshot.dart';

/// `permission_handler` 기반 [PermissionService] 구현
///
/// 플랫폼 차이를 여기서 흡수한다 — 도메인과 화면은 플랫폼을 모른다
/// (docs/05-PLATFORM.md).
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  @override
  Future<PermissionSnapshot> check() async {
    return PermissionSnapshot(
      location: _map(await ph.Permission.locationWhenInUse.status),
      backgroundLocation: _map(await ph.Permission.locationAlways.status),
      notification: _map(await ph.Permission.notification.status),
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
    }
    return check();
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

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
