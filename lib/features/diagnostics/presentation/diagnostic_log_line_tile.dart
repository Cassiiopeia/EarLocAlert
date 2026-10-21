import 'package:flutter/material.dart';

import '../../../core/diagnostics/diagnostic_line.dart';
import '../../../core/text/two_digits.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';

/// 로그 한 줄: 출처·태그 알약 + 시각(밀리초) + 내용, 문제 줄은 위험색 (이슈 #290)
class DiagnosticLogLineTile extends StatelessWidget {
  const DiagnosticLogLineTile({
    super.key,
    required this.line,
    required this.sourceLabel,
  });

  final DiagnosticLine line;
  final String sourceLabel;

  // 문제 줄 왼쪽 표시선 두께 (dp)
  static const _problemMarkerWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isProblem = line.isProblem;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isProblem ? colors.danger : Colors.transparent,
            width: _problemMarkerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs / 2,
              runSpacing: AppSpacing.xs / 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LabelPill(text: sourceLabel),
                if (line.tag.isNotEmpty) _LabelPill(text: line.tag),
                Text(
                  line.hasTimestamp ? _localTime(line.at) : '-',
                  style: context.appTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs / 2),
            SelectableText(
              line.message,
              style: context.appTextStyles.code.copyWith(
                color: isProblem ? colors.danger : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `10/21 15:03:22.481` — 같은 초 안 순서까지 보이게 밀리초 포함 (지역 시각)
  String _localTime(DateTime at) {
    final local = at.toLocal();
    final milliseconds = local.millisecond.toString().padLeft(3, '0');
    return '${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}.$milliseconds';
  }
}

/// 출처·태그 알약 (다른 화면 칩과 같은 모양, #229)
class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: context.appTextStyles.caption),
    );
  }
}
