import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import 'arrival_alarm_coordinator.dart';
import 'background/arrival_alarm_channel.dart';
import '../features/alert/data/alert_providers.dart';

part 'arrival_alarm_providers.g.dart';

/// 잠금 화면 알람(AlarmKit) 사용 여부 (이슈 #252, 결정 074)
/// false: 알람이 뜨면 앱 오디오 세션이 끊겨 이어폰 소리·백그라운드 진동이 멈춤 (실기기)
/// 다시 켜기 = true (Swift `ArrivalAlarm` 은 그대로 둠)
const isLockScreenAlarmEnabled = false;

/// 잠금 화면 알람 (이슈 #235). AlarmKit 은 iOS 에만 있다
@Riverpod(keepAlive: true)
ArrivalAlarmPlatform arrivalAlarmPlatform(Ref ref) {
  if (!Platform.isIOS) return const UnsupportedArrivalAlarm();
  if (!isLockScreenAlarmEnabled) {
    // 이후 `[alarm] skipped reason=unsupported` 가 OS 미지원이 아니라 스위치 때문임을 가림
    Diagnostics.log('alarm', 'lock screen alarm disabled reason=switch_off');
    return const UnsupportedArrivalAlarm();
  }
  return const ArrivalAlarmChannel();
}

/// 세션과 알람을 함께 띄우고 끈다. 앱 수명 동안 하나여야 "지금 떠 있는 알람"을 안다
@Riverpod(keepAlive: true)
ArrivalAlarmCoordinator arrivalAlarmCoordinator(Ref ref) {
  final coordinator = ArrivalAlarmCoordinator(
    platform: ref.watch(arrivalAlarmPlatformProvider),
    isRinging: () => ref.read(alertControllerProvider).current != null,
    // 알림 화면의 해제와 같은 경로다 — 진동·소리가 멈춘다. 광고는 붙이지 않는다
    // (화면 없는 해제라 그 뒤에 띄울 화면이 없다, CLAUDE.md 규칙 1·3)
    dismissSession: () async {
      await ref.read(activeAlertProvider.notifier).dismiss();
    },
  );
  coordinator.attach();
  return coordinator;
}

/// 설정 화면이 보여줄 상태. 시스템 설정에서 돌아오면 다시 읽는다
@riverpod
Future<ArrivalAlarmStatus> arrivalAlarmStatus(Ref ref) =>
    ref.watch(arrivalAlarmPlatformProvider).status();
