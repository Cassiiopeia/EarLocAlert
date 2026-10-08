import 'package:flutter/services.dart';

import '../../../core/platform/channel_names.dart';

import 'vibration_service_impl.dart';

/// iOS 시스템 진동 채널 (이슈 #235)
///
/// 네이티브는 `kSystemSoundID_Vibrate` 만 울린다 — 진동이지 소리가 아니다.
/// 이어폰 판정과 소리는 여전히 Dart 의 `AlertController` 가 맡는다 (CLAUDE.md 규칙 2).
class IosSystemVibration implements SystemVibration {
  IosSystemVibration({
    required bool Function() isBackground,
    MethodChannel? channel,
  }) : _isBackground = isBackground,
       _channel = channel ?? const MethodChannel(channelName);

  static const channelName = ChannelNames.systemVibration;

  final bool Function() _isBackground;
  final MethodChannel _channel;

  @override
  bool shouldUse() => _isBackground();

  @override
  Future<void> pulse() => _channel.invokeMethod<void>('vibrate');
}
