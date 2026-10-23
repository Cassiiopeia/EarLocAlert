import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/platform/channel_names.dart';

/// Swift `VibrationTestNotification` 과 맺은 채널 (이슈 #301)
///
/// 실패는 던지지 않고 false 로 돌려준다 — 점검 시트가 이것 때문에 닫히면 안 된다
class VibrationTestNotificationChannel {
  const VibrationTestNotificationChannel();

  static const _channel = MethodChannel(ChannelNames.vibrationTestNotification);

  /// [delaySeconds] 뒤 도착 알림과 같은 무음 알림음으로 시험 알림 1건 예약
  Future<bool> schedule({
    required String title,
    required String body,
    required int delaySeconds,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('schedule', {
            'title': title,
            'body': body,
            'delaySeconds': delaySeconds.toDouble(),
          }) ??
          false;
    } on Object catch (error) {
      Diagnostics.log('vibration', 'test notification schedule error=$error');
      return false;
    }
  }

  /// 대기·표시 중인 시험 알림 제거
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Object catch (error) {
      Diagnostics.log('vibration', 'test notification cancel error=$error');
    }
  }

  /// 설정 > 알림 > 이 앱 열기 (iOS 16 미만은 이 앱 설정 페이지)
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on Object catch (error) {
      Diagnostics.log('vibration', 'notification settings open error=$error');
      return false;
    }
  }
}
