part of '../place_map_home_screen.dart';

// 상단 알약을 누르면 뜨는 현재 상태 시트 (이슈 #306)

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({
    required this.isMonitoring,
    required this.isBroken,
    required this.isChecking,
    required this.isHeadphoneConnected,
    required this.onFixMonitoring,
  });

  final bool isMonitoring;
  final bool isBroken;
  final bool isChecking;
  final bool isHeadphoneConnected;

  /// 고장일 때만 쓴다 — 권한 화면으로 보내는 해결 경로
  final VoidCallback? onFixMonitoring;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final colors = context.appColors;

    final monitoringColor = isMonitoring
        ? semantic.statusActive
        : isBroken
        ? semantic.statusInactive
        : colors.textSecondary;

    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.radar_outlined,
      title: l10n.homeStatusSheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusSheetRow(
            icon: isMonitoring
                ? Icons.radar_outlined
                : isBroken
                ? Icons.warning_amber_outlined
                : isChecking
                ? Icons.hourglass_empty_outlined
                : Icons.pause_circle_outlined,
            color: monitoringColor,
            title: isMonitoring
                ? l10n.placeHomeStatusWatching
                : isBroken
                ? l10n.placeHomeStatusOff
                : isChecking
                ? l10n.placeHomeStatusChecking
                : l10n.placeHomeStatusIdle,
            description: isMonitoring
                ? l10n.homeStatusWatchingDescription
                : isBroken
                ? l10n.homeStatusOffDescription
                : isChecking
                ? l10n.homeStatusCheckingDescription
                : l10n.homeStatusIdleDescription,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusSheetRow(
            icon: isHeadphoneConnected
                ? Icons.headphones_outlined
                : Icons.vibration_outlined,
            color: isHeadphoneConnected
                ? semantic.audioBluetooth
                : colors.textSecondary,
            title: isHeadphoneConnected
                ? l10n.placeHomeAudioHeadphones
                : l10n.placeHomeAudioVibrationOnly,
            description: isHeadphoneConnected
                ? l10n.homeAudioHeadphonesDescription
                : l10n.homeAudioVibrationOnlyDescription,
          ),
        ],
      ),
      primaryAction: isBroken && onFixMonitoring != null
          ? FilledButton(
              onPressed: onFixMonitoring,
              child: Text(l10n.homeStatusFixButton),
            )
          : null,
    );
  }
}

/// 아이콘 + 제목 + 한 줄 설명
class _StatusSheetRow extends StatelessWidget {
  const _StatusSheetRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.standard, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.appTextStyles.headline.copyWith(color: color),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                context.keepAllText(description),
                style: context.appTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
