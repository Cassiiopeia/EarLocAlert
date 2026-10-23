import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/ios_vibration_check_state.dart';
import 'ios_settings_guide_page.dart';
import 'ios_settings_mockup.dart';
import 'vibration_check_readiness_page.dart';
import 'vibration_test_countdown_ring.dart';

/// 진동 점검 시트의 사용자 동작 묶음 (app 계층 컨트롤러가 채움)
class IosVibrationCheckActions {
  const IosVibrationCheckActions({
    required this.onOpenNotificationSettings,
    required this.onSendTestNotification,
    required this.onCancelWaiting,
    required this.onAnswerFelt,
    required this.onAnswerNotFelt,
    required this.onAnswerNoNotification,
    required this.onOpenAppSettings,
    required this.onNextGuideStep,
    required this.onRestart,
    required this.onGiveUp,
    required this.onClose,
  });

  final VoidCallback onOpenNotificationSettings;

  /// 시험 알림 문구는 화면이 현재 언어로 넘긴다
  final void Function({required String title, required String body})
  onSendTestNotification;
  final VoidCallback onCancelWaiting;
  final VoidCallback onAnswerFelt;
  final VoidCallback onAnswerNotFelt;
  final VoidCallback onAnswerNoNotification;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onNextGuideStep;
  final VoidCallback onRestart;
  final VoidCallback onGiveUp;
  final VoidCallback onClose;
}

/// iOS 진동 점검 시트 (이슈 #301) — 단계마다 한 장, 시트 안에서 바뀐다
class IosVibrationCheckSheet extends StatelessWidget {
  const IosVibrationCheckSheet({
    required this.state,
    required this.actions,
    super.key,
  });

  final IosVibrationCheckState state;
  final IosVibrationCheckActions actions;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey('${state.step.name}-${state.attempt}'),
          child: _buildPage(context),
        ),
      ),
    );
  }

  void _sendTest(BuildContext context) => actions.onSendTestNotification(
    title: context.l10n.vibrationCheckNotificationTitle,
    body: context.l10n.vibrationCheckNotificationBody,
  );

  Widget _buildPage(BuildContext context) {
    final l10n = context.l10n;
    return switch (state.step) {
      IosVibrationCheckStep.readiness => VibrationCheckReadinessPage(
        state: state,
        onOpenNotificationSettings: actions.onOpenNotificationSettings,
        onSendTest: () => _sendTest(context),
        onLater: actions.onClose,
      ),
      IosVibrationCheckStep.waitingForLock => BottomSheetWithHeaderLayout(
        headerIcon: Icons.lock_outline,
        title: l10n.vibrationCheckWaitingTitle,
        description: l10n.vibrationCheckWaitingBody(
          testNotificationDelaySeconds,
        ),
        body: const Center(child: VibrationTestCountdownRing()),
        secondaryAction: TextButton(
          onPressed: actions.onCancelWaiting,
          child: Text(l10n.vibrationCheckCancel),
        ),
      ),
      IosVibrationCheckStep.screenNotLocked => BottomSheetWithHeaderLayout(
        headerIcon: Icons.lock_open_outlined,
        title: l10n.vibrationCheckNotLockedTitle,
        description: l10n.vibrationCheckNotLockedBody,
        body: const SizedBox.shrink(),
        primaryAction: FilledButton(
          onPressed: () => _sendTest(context),
          child: Text(l10n.vibrationCheckTryAgain),
        ),
        secondaryAction: TextButton(
          onPressed: actions.onClose,
          child: Text(l10n.vibrationCheckLater),
        ),
      ),
      IosVibrationCheckStep.askingResult => _AskResultPage(
        onFelt: actions.onAnswerFelt,
        onNotFelt: actions.onAnswerNotFelt,
        onNoNotification: actions.onAnswerNoNotification,
        onTryAgain: () => _sendTest(context),
      ),
      IosVibrationCheckStep.guideHaptics ||
      IosVibrationCheckStep.guideAccessibilityVibration ||
      IosVibrationCheckStep.guideFocusMode => IosSettingsGuidePage(
        step: state.step,
        onOpenAppSettings: actions.onOpenAppSettings,
        onChanged: state.step == IosVibrationCheckStep.guideFocusMode
            ? actions.onRestart
            : actions.onNextGuideStep,
        onGiveUp: actions.onGiveUp,
      ),
      IosVibrationCheckStep.succeeded => BottomSheetWithHeaderLayout(
        headerIcon: Icons.check_circle_outline,
        title: l10n.vibrationCheckSuccessTitle,
        description: l10n.vibrationCheckSuccessBody,
        body: const Center(child: _SuccessBadge()),
        primaryAction: FilledButton(
          onPressed: actions.onClose,
          child: Text(l10n.vibrationCheckDone),
        ),
      ),
      IosVibrationCheckStep.stillNotVibrating => BottomSheetWithHeaderLayout(
        headerIcon: Icons.help_outline,
        title: l10n.vibrationCheckStillTitle,
        description: l10n.vibrationCheckStillBody,
        body: IosSettingsPath(
          segments: [
            l10n.iosSettingsRoot,
            l10n.iosSettingsSoundsAndHaptics,
            l10n.iosSettingsRingtone,
            l10n.iosSettingsRingtoneHapticsNotNone,
          ],
        ),
        primaryAction: FilledButton(
          onPressed: actions.onRestart,
          child: Text(l10n.vibrationCheckTryAgain),
        ),
        secondaryAction: TextButton(
          onPressed: actions.onClose,
          child: Text(l10n.vibrationCheckClose),
        ),
      ),
    };
  }
}

/// ④ 결과 묻기 — 느꼈어요/못 느꼈어요를 나란히 크게
class _AskResultPage extends StatelessWidget {
  const _AskResultPage({
    required this.onFelt,
    required this.onNotFelt,
    required this.onNoNotification,
    required this.onTryAgain,
  });

  final VoidCallback onFelt;
  final VoidCallback onNotFelt;
  final VoidCallback onNoNotification;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.vibration_outlined,
      title: l10n.vibrationCheckAskTitle,
      description: l10n.vibrationCheckAskBody,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onNotFelt,
                  child: Text(l10n.vibrationCheckAnswerNotFelt),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  onPressed: onFelt,
                  child: Text(l10n.vibrationCheckAnswerFelt),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onNoNotification,
            child: Text(l10n.vibrationCheckAnswerNoNotification),
          ),
          TextButton(
            onPressed: onTryAgain,
            child: Text(l10n.vibrationCheckTryAgain),
          ),
        ],
      ),
    );
  }
}

/// 성공 표시 (민트 원 안의 체크)
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  static const double _diameter = 96;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: AppIconSize.hero,
        color: palette.accent,
      ),
    );
  }
}
