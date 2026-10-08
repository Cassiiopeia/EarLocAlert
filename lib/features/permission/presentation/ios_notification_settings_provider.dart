import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/ios_notification_settings_channel.dart';
import '../domain/ios_notification_settings.dart';

part 'ios_notification_settings_provider.g.dart';

/// iOS 알림 설정 (이슈 #237). iOS 가 아니면 읽을 것이 없어 null 이다.
///
/// 시스템 설정에서 돌아오면 무효화해서 다시 읽는다 — 사용자가 방금 켰을 수 있다.
@riverpod
Future<IosNotificationSettings?> iosNotificationSettings(Ref ref) async {
  if (!Platform.isIOS) return null;
  return const IosNotificationSettingsChannel().read();
}
