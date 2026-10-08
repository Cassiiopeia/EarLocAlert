import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/domain/vibration_check.dart';
import '../features/alert/presentation/vibration_check_provider.dart';
import '../features/permission/domain/ios_notification_settings.dart';
import '../features/permission/presentation/ios_notification_settings_provider.dart';
import 'arrival_alarm_providers.dart';
import 'background/arrival_alarm_channel.dart';
import 'reliability_gap.dart';

part 'ios_alert_readiness.g.dart';

/// iOS 에서 도착을 놓치게 만드는 설정을 고른다 (이슈 #237).
///
/// **막는 것만 고른다.** 사용자가 바로 고칠 수 있고, 고치지 않으면 도착이 그냥
/// 지나가는 것만 홈 경고에 올린다:
/// - 알림이 허용되지 않았다
/// - 잠금 화면 표시가 꺼졌다 (알림이 막혔으면 그쪽이 먼저라 겹쳐 올리지 않는다)
/// - 잠금 화면 알람을 거부했다 (iOS 26+ 에서만 있다)
/// - 진동 시험에서 느껴지지 않았다고 답했다
///
/// 시간 민감 알림이 꺼진 것은 올리지 않는다 — 앱에 그 권한(entitlement)이 아직 없어
/// 사용자가 켤 수도 없다. 기록만 남긴다.
///
/// **모르는 값은 막힌 것이 아니다** — 읽지 못했다고 경고부터 띄우지 않는다 (#142 QA).
List<ReliabilityGap> iosAlertGaps({
  required IosNotificationSettings? notifications,
  required ArrivalAlarmStatus? alarm,
  required VibrationCheckResult? vibration,
}) {
  final notificationsBlocked = notifications?.isBlocked ?? false;
  return [
    if (notificationsBlocked) ReliabilityGap.notifications,
    if (!notificationsBlocked &&
        notifications?.lockScreen == IosNotificationSetting.disabled)
      ReliabilityGap.lockScreen,
    if (alarm != null &&
        alarm.supported &&
        alarm.authorization == ArrivalAlarmAuthorization.denied)
      ReliabilityGap.lockScreenAlarm,
    if (vibration != null && !vibration.felt) ReliabilityGap.vibration,
  ];
}

/// 마지막으로 남긴 iOS 알림 설정 줄 — 바뀐 경우에만 남긴다 (#146 과 같은 이유)
String? _lastLoggedSettings;

/// iOS 에서 도착을 놓치게 만드는 항목들 (이슈 #237). iOS 가 아니면 늘 비어 있다.
///
/// 앱이 전면으로 돌아올 때 [iosNotificationSettingsProvider] 와
/// [arrivalAlarmStatusProvider] 를 무효화하면 다시 계산된다.
@riverpod
Future<List<ReliabilityGap>> iosAlertReadiness(Ref ref) async {
  if (!Platform.isIOS) return const [];

  final notifications = await ref.watch(iosNotificationSettingsProvider.future);
  ArrivalAlarmStatus? alarm;
  try {
    alarm = await ref.watch(arrivalAlarmStatusProvider.future);
  } on Object {
    alarm = null;
  }
  VibrationCheckResult? vibration;
  try {
    vibration = await ref.watch(vibrationCheckProvider.future);
  } on Object {
    vibration = null;
  }

  // 읽을 수 있는 값을 한 줄에 전부 남긴다 — "왜 잠금 화면에 아무것도 안 떴나"는
  // 이 줄 없이는 가릴 수 없다
  final line =
      'ios notification settings '
      'auth=${notifications?.authorization.name ?? "none"} '
      'lock_screen=${notifications?.lockScreen.name ?? "none"} '
      'alert=${notifications?.alert.name ?? "none"} '
      'notification_center=${notifications?.notificationCenter.name ?? "none"} '
      'sound=${notifications?.sound.name ?? "none"} '
      'time_sensitive=${notifications?.timeSensitive.name ?? "none"} '
      'alarm=${alarm?.authorization.name ?? "none"} '
      'vibration_felt=${vibration?.felt.toString() ?? "untested"}';
  if (line != _lastLoggedSettings) {
    _lastLoggedSettings = line;
    Diagnostics.log('permission', line);
  }

  return iosAlertGaps(
    notifications: notifications,
    alarm: alarm,
    vibration: vibration,
  );
}
