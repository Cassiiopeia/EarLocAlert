part of '../place_map_home_screen.dart';

// 알림 약함 경고 캡슐

/// 알림이 약할 때 상태 알약 오른쪽에 붙는 캡슐 (이슈 #74, #115, #310)
///
/// 배너가 한 줄을 차지하던 것을 알약 안으로 접었다. 경고가 있을 때만 붙고,
/// 알약 전체가 탭 영역이라 따로 누를 곳은 없다. 상세와 켜기 버튼은 상태 카드에 있다.
/// 고장(감시 꺼짐)은 아니라서 빨강이 아니라 경고색(금색)을 쓴다
class _WeakAlertCapsule extends StatelessWidget {
  const _WeakAlertCapsule();

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.warning;
    final label = context.l10n.placeHomeWeakChip;
    final labelStyle = context.appTextStyles.caption.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
    );
    const horizontalPadding = AppSpacing.xs;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 글자가 다 들어갈 때만 보인다 — 잘려 "알..." 이 되느니 아이콘만 둔다.
        // FREE 칩이 붙는 폰이나 긴 번역에서 폭이 모자란다
        final labelPainter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        const fixedWidth =
            horizontalPadding * 2 + AppIconSize.control * 2 + AppSpacing.xs / 2;
        final isLabelVisible =
            fixedWidth + labelPainter.width <= constraints.maxWidth;
        labelPainter.dispose();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppSpacing.xs / 2,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: AppIconSize.control,
                color: accent,
              ),
              if (isLabelVisible) ...[
                const SizedBox(width: AppSpacing.xs / 2),
                Text(label, maxLines: 1, style: labelStyle),
              ],
              Icon(
                Icons.chevron_right_outlined,
                size: AppIconSize.control,
                color: accent,
              ),
            ],
          ),
        );
      },
    );
  }
}
