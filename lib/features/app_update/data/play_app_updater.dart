import 'dart:io' show Platform;

import 'package:in_app_update/in_app_update.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/app_updater.dart';

/// Google Play 앱 내 업데이트 구현 (이슈 #170)
///
/// Play 에서 설치한 빌드에서만 동작한다. 개발 빌드·직접 받은 APK 에서는
/// 확인이 예외로 실패하는데 정상이므로 로그만 남기고 넘어간다.
/// **Android 전용이다** — iOS 는 앱 내 업데이트가 없다.
class PlayAppUpdater implements AppUpdater {
  const PlayAppUpdater();

  @override
  Future<bool> updateAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed;
      Diagnostics.log(
        'update',
        'check result available=$available '
            'availableVersionCode=${info.availableVersionCode} '
            'flexibleAllowed=${info.flexibleUpdateAllowed}',
      );
      return available;
    } on Object catch (error) {
      // Play 밖 설치 등 — 정상 경로다
      Diagnostics.log('update', 'check failed $error');
      return false;
    }
  }

  @override
  Future<bool> download() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      Diagnostics.log('update', 'download result=${result.name}');
      return result == AppUpdateResult.success;
    } on Object catch (error) {
      Diagnostics.log('update', 'download failed $error');
      return false;
    }
  }

  @override
  Future<void> install() async {
    try {
      Diagnostics.log('update', 'install requested');
      await InAppUpdate.completeFlexibleUpdate();
    } on Object catch (error) {
      Diagnostics.log('update', 'install failed $error');
    }
  }
}
