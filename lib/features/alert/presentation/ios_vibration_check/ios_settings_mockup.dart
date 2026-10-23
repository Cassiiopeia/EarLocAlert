import 'package:flutter/material.dart';

import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';

/// 설정 경로 칩 (설정 › 사운드 및 햅틱 › 햅틱). 마지막 칸이 목적지
class IosSettingsPath extends StatelessWidget {
  const IosSettingsPath({required this.segments, super.key});

  final List<String> segments;

  /// 칩 안쪽 여백 — 간격 토큰 사이 값이라 칩 전용으로 둔다
  static const EdgeInsets _chipPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 5,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Wrap(
      spacing: 4,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, segment) in segments.indexed) ...[
          if (index > 0)
            Icon(
              Icons.chevron_right,
              size: AppIconSize.inline,
              color: palette.textSecondary,
            ),
          Container(
            padding: _chipPadding,
            decoration: BoxDecoration(
              color: index == segments.length - 1
                  ? palette.accent.withValues(alpha: 0.16)
                  : palette.elevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              segment,
              style: context.appTextStyles.caption.copyWith(
                color: index == segments.length - 1
                    ? palette.accent
                    : palette.textPrimary,
                fontWeight: index == segments.length - 1
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _MockupTrailing { choice, toggle, navigation }

/// 설정 화면 모형의 한 줄
class IosSettingsMockupRow {
  const IosSettingsMockupRow.choice(this.label, {this.isTarget = false})
    : _trailing = _MockupTrailing.choice;
  const IosSettingsMockupRow.toggle(this.label, {this.isTarget = false})
    : _trailing = _MockupTrailing.toggle;
  const IosSettingsMockupRow.navigation(this.label, {this.isTarget = false})
    : _trailing = _MockupTrailing.navigation;

  final String label;

  /// 사용자가 바꿔야 하는 줄 — 강조 테두리와 맞는 값(체크·켜짐)
  final bool isTarget;
  final _MockupTrailing _trailing;
}

/// iOS 설정 화면 모형 (배경 위 둥근 묶음 카드)
class IosSettingsMockup extends StatelessWidget {
  const IosSettingsMockup({
    required this.sectionTitle,
    required this.rows,
    super.key,
  });

  final String sectionTitle;
  final List<IosSettingsMockupRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Text(sectionTitle, style: context.appTextStyles.caption),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Column(
              children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: AppSpacing.sm,
                      color: palette.separator,
                    ),
                  _MockupRow(row: row),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockupRow extends StatelessWidget {
  const _MockupRow({required this.row});

  final IosSettingsMockupRow row;

  /// 모형 스위치 크기 (iOS 스위치 비율)
  static const double _toggleWidth = 44;
  static const double _toggleHeight = 26;
  static const double _toggleKnob = 22;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final trailing = switch (row._trailing) {
      _MockupTrailing.choice =>
        row.isTarget
            ? Icon(
                Icons.check,
                size: AppIconSize.control,
                color: palette.accent,
              )
            : null,
      _MockupTrailing.toggle => Container(
        width: _toggleWidth,
        height: _toggleHeight,
        padding: const EdgeInsets.all((_toggleHeight - _toggleKnob) / 2),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Container(
          width: _toggleKnob,
          height: _toggleKnob,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
      _MockupTrailing.navigation => Icon(
        Icons.chevron_right,
        size: AppIconSize.control,
        color: palette.textSecondary,
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: row.isTarget
          ? BoxDecoration(
              color: palette.accent.withValues(alpha: 0.10),
              border: Border.all(color: palette.accent, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.small),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: context.appTextStyles.body.copyWith(
                fontWeight: row.isTarget ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
