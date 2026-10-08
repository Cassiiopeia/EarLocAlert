import 'package:flutter/services.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/platform/channel_names.dart';
import '../domain/ios_notification_settings.dart';

/// Swift `NotificationSettingsReader` 와 맺은 채널 (이슈 #237)
class IosNotificationSettingsChannel {
  const IosNotificationSettingsChannel();

  static const _channel = MethodChannel(ChannelNames.notificationSettings);

  /// 읽지 못하면 [IosNotificationSettings.unknown] — **던지지 않는다.**
  /// 홈 상태 표시가 이것 때문에 깨지면 안 된다
  Future<IosNotificationSettings> read() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('read');
      return IosNotificationSettings.fromMap(raw);
    } on Object catch (error) {
      Diagnostics.log(
        'permission',
        'ios notification settings read failed error=$error',
      );
      return IosNotificationSettings.unknown;
    }
  }
}
