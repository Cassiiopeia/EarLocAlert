import 'package:flutter/services.dart';

import '../domain/full_screen_intent_gate.dart';
import '../domain/permission_kind.dart';

/// 전체화면 알림 권한의 네이티브 구현 (이슈 #74)
///
/// 네이티브는 `NotificationManager.canUseFullScreenIntent()`(API 34+)를
/// 읽고, 요청은 `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` 설정 화면으로
/// 보낸다. API 33 이하는 매니페스트 선언만으로 부여되므로 항상 true 다.
///
/// **채널이 없어도 실패하지 않는다** — iOS 나 채널 등록 전 호출에서는
/// 허용으로 본다. 확인 실패를 막힘으로 처리하면 온보딩이 헛돈다.
class FullScreenIntentChannel implements FullScreenIntentGate {
  const FullScreenIntentChannel();

  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/alert_reliability',
  );

  @override
  Future<PermissionStatus> status() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      // null 은 판단 근거가 없다는 뜻 — 막지 않는다
      if (granted == null || granted) return PermissionStatus.granted;
      // 설정 화면에서만 켤 수 있다 — 앱 내 재요청이 통하지 않는다
      return PermissionStatus.permanentlyDenied;
    } on Object {
      return PermissionStatus.granted;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } on Object {
      // 설정 화면을 못 열어도 온보딩은 계속된다
    }
  }
}
