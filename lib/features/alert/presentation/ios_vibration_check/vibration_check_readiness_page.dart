import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../../core/ui/components/loading_indicator.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/ios_vibration_check_state.dart';

/// ① 읽을 수 있는 설정 3개 + 시험으로만 아는 햅틱
class VibrationCheckReadinessPage extends StatelessWidget {
  const VibrationCheckReadinessPage({
    super.key,
    required this.state,
    required this.onOpenNotificationSettings,
    required this.onSendTest,
    required this.onLater,
  });

  final IosVibrationCheckState state;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onSendTest;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.appColors;
    final hasBlockers = state.blockers.isNotEmpty;

    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.vibration_outlined,
      title: l10n.vibrationCheckTitle,
      description: l10n.vibrationCheckDescription,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Column(
              children: [
                for (final blocker in VibrationCheckBlocker.values)
                  _ReadinessRow(
                    icon: _iconOf(blocker),
                    label: _labelOf(l10n, blocker),
                    status: !state.hasReadSettings
                        ? _ReadinessStatus.reading
                        : state.blockers.contains(blocker)
                        ? _ReadinessStatus.off
                        : _ReadinessStatus.on,
                  ),
                _ReadinessRow(
                  icon: Icons.vibration_outlined,
                  label: l10n.vibrationCheckItemHaptics,
                  status: _ReadinessStatus.byTest,
                ),
              ],
            ),
          ),
          if (hasBlockers) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.keepAllText(l10n.vibrationCheckBlockedHint),
              style: context.appTextStyles.caption.copyWith(
                color: palette.warning,
              ),
            ),
          ],
          if (state.isScheduleFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.keepAllText(l10n.vibrationCheckScheduleFailed),
              style: context.appTextStyles.caption.copyWith(
                color: palette.danger,
              ),
            ),
          ],
        ],
      ),
      // 꺼진 항목이 있으면 시험보다 먼저 고친다 — 켜지 않고 시험하면 결과가 뻔하다
      primaryAction: hasBlockers
          ? FilledButton(
              onPressed: onOpenNotificationSettings,
              child: Text(l10n.vibrationCheckOpenNotificationSettings),
            )
          : FilledButton(
              onPressed: state.canSendTest ? onSendTest : null,
              child: Text(l10n.vibrationCheckSendTest),
            ),
      secondaryAction: TextButton(
        onPressed: onLater,
        child: Text(l10n.vibrationCheckLater),
      ),
    );
  }

  static IconData _iconOf(VibrationCheckBlocker blocker) => switch (blocker) {
    VibrationCheckBlocker.notificationsNotAllowed =>
      Icons.notifications_outlined,
    VibrationCheckBlocker.lockScreenHidden => Icons.lock_outline,
    VibrationCheckBlocker.notificationSoundOff => Icons.volume_up_outlined,
  };

  static String _labelOf(
    AppLocalizations l10n,
    VibrationCheckBlocker blocker,
  ) => switch (blocker) {
    VibrationCheckBlocker.notificationsNotAllowed =>
      l10n.vibrationCheckItemNotifications,
    VibrationCheckBlocker.lockScreenHidden => l10n.vibrationCheckItemLockScreen,
    VibrationCheckBlocker.notificationSoundOff => l10n.vibrationCheckItemSound,
  };
}

/// 확인 줄 상태: 읽는 중 · 켜짐 · 꺼짐 · 시험으로 확인
enum _ReadinessStatus { reading, on, off, byTest }

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final _ReadinessStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.appColors;
    final (statusIcon, statusText, statusColor) = switch (status) {
      _ReadinessStatus.reading => (null, null, palette.textSecondary),
      _ReadinessStatus.on => (
        Icons.check_circle,
        l10n.vibrationCheckStatusOn,
        palette.accent,
      ),
      _ReadinessStatus.off => (
        Icons.error,
        l10n.vibrationCheckStatusOff,
        palette.warning,
      ),
      _ReadinessStatus.byTest => (
        Icons.help,
        l10n.vibrationCheckStatusByTest,
        palette.textSecondary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.control, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.appTextStyles.body)),
          if (status == _ReadinessStatus.reading)
            const InlineLoadingIndicator()
          else ...[
            Text(
              statusText!,
              style: context.appTextStyles.caption.copyWith(
                color: statusColor,
                fontWeight: status == _ReadinessStatus.off
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            Icon(statusIcon, size: AppIconSize.inline, color: statusColor),
          ],
        ],
      ),
    );
  }
}
