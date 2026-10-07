import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/diagnostics.dart';

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

  /// iOS 에서 "항상" 허용을 시스템 창으로 이미 물었는지 (이슈 #216)
  static const _iosAlwaysAskedKey = 'permission.ios_always_asked';

  @override
  Future<PermissionSnapshot> check() async {
    final location = _map(await ph.Permission.locationWhenInUse.status);
    return PermissionSnapshot(
      location: location,
      backgroundLocation: await _backgroundLocationStatus(location),
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
          // 묻기 전에 "물었다"를 먼저 적는다. 창이 떠 있는 동안 앱이 종료돼도
          // 다음 실행에서 같은 창을 또 요청하지 않는다 — iOS 는 이 창을 한 번만 보여준다
          await _markIosAlwaysAsked();
          await ph.Permission.locationAlways.request();
          Diagnostics.log(
            'permission',
            'ios always location requested result='
                '${(await ph.Permission.locationAlways.status).name}',
          );
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

  /// "항상" 위치 상태.
  ///
  /// **iOS 는 "앱을 사용하는 동안" 허용 직후의 "항상"을 영구 거부로 보고한다**
  /// (`permission_handler_apple` 의 `determinePermissionStatus`). 그대로 두면
  /// 게이트가 이 단계를 건너뛰어 시스템 창이 한 번도 뜨지 않고 설정으로 보낸다 (이슈 #216).
  Future<PermissionStatus> _backgroundLocationStatus(
    PermissionStatus whenInUse,
  ) async {
    final reported = _map(await ph.Permission.locationAlways.status);
    if (!Platform.isIOS) return reported;
    return iosBackgroundLocationStatus(
      reported: reported,
      whenInUse: whenInUse,
      alreadyAsked: await _wasIosAlwaysAsked(),
    );
  }

  Future<bool> _wasIosAlwaysAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_iosAlwaysAskedKey) ?? false;
    } on Object catch (error) {
      // 읽지 못하면 "아직 안 물었다"로 본다 — 한 번 더 묻는 쪽이 설정으로 곧장 보내는 쪽보다 낫다
      Diagnostics.log(
        'permission',
        'ios always asked flag read failed error=$error',
      );
      return false;
    }
  }

  Future<void> _markIosAlwaysAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_iosAlwaysAskedKey, true);
    } on Object catch (error) {
      Diagnostics.log(
        'permission',
        'ios always asked flag write failed error=$error',
      );
    }
  }

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

/// iOS 의 "항상" 위치 상태를 게이트가 읽을 수 있게 보정한다 (이슈 #216).
///
/// 플러그인은 "앱을 사용하는 동안"만 허용된 상태를 영구 거부로 돌려준다. 그 상태에서
/// 아직 시스템 창을 한 번도 띄우지 않았다면 **요청 가능**으로 바꿔 줘야 단계가 나온다.
/// 이미 물었다면 iOS 가 다시 묻지 않으므로 영구 거부 그대로 둬 설정 안내로 보낸다.
@visibleForTesting
PermissionStatus iosBackgroundLocationStatus({
  required PermissionStatus reported,
  required PermissionStatus whenInUse,
  required bool alreadyAsked,
}) {
  if (reported != PermissionStatus.permanentlyDenied) return reported;
  if (!whenInUse.isGranted) return reported;
  if (alreadyAsked) return reported;
  return PermissionStatus.denied;
}
