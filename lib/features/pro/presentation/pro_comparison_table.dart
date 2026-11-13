import 'package:flutter/material.dart';

import '../../../core/domain/vibration_pattern.dart';
import '../../../core/entitlement/place_limits.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../domain/pro_offer_entry.dart';

/// 무료·프로 비교표 (#366): 기본 알림 1줄 + 프로 혜택 8줄, 들어온 자리의 혜택 줄을 민트 면으로 강조
class ProComparisonTable extends StatelessWidget {
  const ProComparisonTable({required this.highlight, super.key});

  /// 강조할 혜택. general 이면 강조 없음
  final ProOfferHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    // 행: (항목, 무료 값, 프로 값, 강조 대상). 값 null = 체크 표시, '' = 불가 표시
    final rows = <(String, String?, String?, ProOfferHighlight?)>[
      // 무료도 그대로인 기본 기능 > 한 줄로 안심시키기
      (l10n.proRowBasics, null, null, null),
      (
        l10n.proRowPlaces,
        l10n.proValueOnePlace,
        l10n.proValueMaxPlaces(PlaceLimits.platformMaximum()),
        ProOfferHighlight.places,
      ),
      (
        l10n.proRowSound,
        l10n.proValueDefaultSound,
        l10n.proValueAllSounds,
        ProOfferHighlight.sounds,
      ),
      (
        l10n.proRowVibrationPattern,
        l10n.proValueDefaultPattern,
        l10n.proValueAllPatterns(VibrationPattern.values.length),
        ProOfferHighlight.vibrationPatterns,
      ),
      (
        l10n.proRowHistory,
        l10n.proValueRecentHistory,
        l10n.proValueFullHistory,
        ProOfferHighlight.history,
      ),
      (l10n.proRowRoutines, '', null, ProOfferHighlight.routines),
      (l10n.proRowBackup, '', null, ProOfferHighlight.backup),
      (l10n.cloudSyncTitle, '', null, ProOfferHighlight.backup),
      (l10n.proRowAds, l10n.proValueAdsOn, l10n.proValueAdsOff, null),
    ];

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: colors.separator),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ComparisonRow(
            label: '',
            isHighlighted: false,
            free: Text(
              l10n.proSheetColumnFree,
              style: context.appTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            pro: Text(
              l10n.proSheetColumnPro,
              style: context.appTextStyles.caption.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          for (final (label, free, pro, rowHighlight) in rows) ...[
            Divider(height: 1, thickness: 1, color: colors.separator),
            _ComparisonRow(
              label: label,
              isHighlighted:
                  highlight != ProOfferHighlight.general &&
                  rowHighlight == highlight,
              free: _ComparisonValue(value: free, isPro: false),
              pro: _ComparisonValue(value: pro, isPro: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.isHighlighted,
    required this.free,
    required this.pro,
  });

  final String label;

  /// 들어온 자리의 혜택 줄인가 > 민트 면 + 굵은 항목명
  final bool isHighlighted;
  final Widget free;
  final Widget pro;

  // 강조 줄 민트 섞는 비율
  static const double _highlightTintRatio = 0.14;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: isHighlighted
          ? Color.lerp(colors.surface, colors.accent, _highlightTintRatio)!
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + AppSpacing.xs / 4,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                context.keepAllText(label),
                style: context.appTextStyles.body.copyWith(
                  fontWeight: isHighlighted ? FontWeight.w700 : null,
                ),
              ),
            ),
            Expanded(flex: 3, child: free),
            Expanded(flex: 4, child: pro),
          ],
        ),
      ),
    );
  }
}

/// 표 칸 값: null 체크 아이콘 / '' 불가(—) / 글자
class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.value, required this.isPro});

  final String? value;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isPro ? colors.accent : colors.textSecondary;
    final text = value;
    if (text == null) {
      return Icon(Icons.check_rounded, size: AppIconSize.inline, color: color);
    }
    return Text(
      text.isEmpty ? '—' : context.keepAllText(text),
      style: context.appTextStyles.caption.copyWith(
        color: color,
        fontWeight: isPro ? FontWeight.w700 : FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }
}
