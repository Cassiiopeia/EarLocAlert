import 'package:flutter/material.dart';

import '../../../core/domain/vibration_pattern.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';

/// 프로 혜택 한 줄: 아이콘, 항목 이름, 프로 값 (null = 체크 표시)
typedef ProBenefit = ({IconData icon, String label, String? value});

/// 프로 혜택 7개 (#352): 문구는 프로 안내 시트 비교표와 같은 키, 아이콘은 설정 화면과 같은 outlined
List<ProBenefit> proBenefitsOf(AppLocalizations l10n) => [
  (
    icon: Icons.place_outlined,
    label: l10n.proRowPlaces,
    value: l10n.proValueUnlimited,
  ),
  (
    icon: Icons.vibration_outlined,
    label: l10n.proRowVibrationPattern,
    value: l10n.proValueAllPatterns(VibrationPattern.values.length),
  ),
  (
    icon: Icons.graphic_eq_outlined,
    label: l10n.proRowSound,
    value: l10n.proValueAllSounds,
  ),
  (
    icon: Icons.history_outlined,
    label: l10n.proRowHistory,
    value: l10n.proValueFullHistory,
  ),
  (icon: Icons.route_outlined, label: l10n.proRowRoutines, value: null),
  (icon: Icons.cloud_sync_outlined, label: l10n.proRowBackup, value: null),
  (
    icon: Icons.block_outlined,
    label: l10n.proRowAds,
    value: l10n.proValueAdsOff,
  ),
];

/// 프로 혜택 목록: 제목 > 항목마다 민트 아이콘 칸 + 이름 + 프로 값
class ProBenefitList extends StatelessWidget {
  const ProBenefitList({super.key});

  // 아이콘 칸 한 변 (dp)
  static const double _iconTileSize = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final benefits = proBenefitsOf(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            l10n.proInfoBenefitsTitle,
            style: context.appTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: colors.separator),
          ),
          child: Column(
            children: [
              for (final (index, benefit) in benefits.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: AppSpacing.sm + _iconTileSize + AppSpacing.sm,
                    color: colors.separator,
                  ),
                _ProBenefitRow(benefit: benefit, iconTileSize: _iconTileSize),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProBenefitRow extends StatelessWidget {
  const _ProBenefitRow({required this.benefit, required this.iconTileSize});

  final ProBenefit benefit;
  final double iconTileSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final value = benefit.value;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          // 아이콘 칸 (민트 옅은 바탕)
          Container(
            width: iconTileSize,
            height: iconTileSize,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.small / 2),
            ),
            child: Icon(
              benefit.icon,
              size: AppIconSize.inline,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              benefit.label,
              style: context.appTextStyles.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (value == null)
            Icon(
              Icons.check_rounded,
              size: AppIconSize.inline,
              color: colors.accent,
            )
          else
            Text(
              value,
              style: context.appTextStyles.caption.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
