import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/config/dev_flag.dart';

import '../domain/app_update.dart';

/// APK 설치 채널 (이슈 #104)
///
/// **왜 네이티브인가** — APK 설치는 `Intent.ACTION_VIEW` 와 FileProvider
/// URI 가 필요하고, Android 8+ 는 "출처를 알 수 없는 앱 설치" 권한을
/// 앱별로 받는다. Dart 에서 할 수 있는 일이 아니다.
///
/// **설치를 대신 하지 않는다.** 설치 화면을 띄우는 것까지가 앱의 일이고,
/// 실제 설치 여부는 사용자가 그 화면에서 정한다.
class AppInstallerChannel {
  const AppInstallerChannel();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/app_installer',
  );

  /// 앱의 현재 버전 이름 (`1.7.2`).
  ///
  /// pubspec 이 아니라 **설치된 APK 의 값**을 읽는다 — 사용자가 실제로
  /// 돌리고 있는 것이 그것이다.
  static Future<String> readVersionName() async {
    if (!Platform.isAndroid) return '';
    try {
      return await _channel.invokeMethod<String>('getVersionName') ?? '';
    } on Object {
      return '';
    }
  }

  /// 이 빌드에 인앱 업데이트가 들어 있는가 (이슈 #109).
  ///
  /// **판정은 [DevFlag] 하나로 모은다** — 광고 종류도 같은 값이 가르므로,
  /// 읽는 자리가 둘이 되면 한쪽만 바뀌어 어긋난다.
  ///
  /// 꺼진 빌드에서는 `REQUEST_INSTALL_PACKAGES` 권한과 FileProvider 선언이
  /// 매니페스트에서 통째로 빠지므로, 화면에 항목을 띄워봐야 눌러도
  /// 실패만 한다.
  static Future<bool> isFeatureEnabled() async {
    if (!Platform.isAndroid) return false;
    await DevFlag.init();
    return DevFlag.isDevBuild;
  }

  /// APK 를 저장하고 설치 화면을 띄운다.
  ///
  /// 저장 위치는 앱 캐시다 — 외부 저장소 권한이 필요 없고, 설치가 끝나면
  /// OS 가 알아서 정리한다.
  Future<void> install({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) {
      throw const AppUpdateException('이 기기에서는 지원하지 않습니다');
    }
    try {
      await _channel.invokeMethod<void>('installApk', {
        'bytes': Uint8List.fromList(bytes),
        'fileName': fileName,
      });
    } on PlatformException catch (error) {
      throw AppUpdateException(error.message ?? '설치를 시작하지 못했습니다');
    }
  }
}
