import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../features/alert/presentation/ios_vibration_check/ios_vibration_check_sheet.dart';
import 'ios_vibration_check_controller.dart';

/// iOS 진동 점검 시트 열기 (이슈 #301)
///
/// 진입점 3개: 온보딩 끝 진동 시험 · 홈 경고 진동 항목 · 설정 "알림이 안 울린다면"
Future<void> showIosVibrationCheckSheet(
  BuildContext context, {
  required String trigger,
}) {
  Diagnostics.log('vibration', 'check sheet shown trigger=$trigger');
  return showAppBottomSheet<void>(
    context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(iosVibrationCheckControllerProvider);
        final controller = ref.read(
          iosVibrationCheckControllerProvider.notifier,
        );
        return IosVibrationCheckSheet(
          state: state,
          actions: IosVibrationCheckActions(
            onOpenNotificationSettings: () =>
                unawaited(controller.openNotificationSettings()),
            onSendTestNotification: ({required title, required body}) =>
                unawaited(
                  controller.sendTestNotification(title: title, body: body),
                ),
            onCancelWaiting: () => unawaited(controller.cancelWaiting()),
            onAnswerFelt: () => unawaited(controller.answerFelt()),
            onAnswerNotFelt: () => unawaited(controller.answerNotFelt()),
            onAnswerNoNotification: () =>
                unawaited(controller.answerNoNotification()),
            onOpenAppSettings: () => unawaited(controller.openAppSettings()),
            onNextGuideStep: controller.goToNextGuideStep,
            onRestart: () => unawaited(controller.restart()),
            onGiveUp: controller.giveUp,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    ),
  );
}
