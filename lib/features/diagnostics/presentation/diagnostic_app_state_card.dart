import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';

/// 앱 상태 카드: 접힌 제목 > 펼치면 권한·장소·설정·네이티브 상태 원문 (이슈 #290)
class DiagnosticAppStateCard extends StatefulWidget {
  const DiagnosticAppStateCard({super.key, required this.appState});

  final String appState;

  @override
  State<DiagnosticAppStateCard> createState() => _DiagnosticAppStateCardState();
}

class _DiagnosticAppStateCardState extends State<DiagnosticAppStateCard> {
  // 화면 로컬 펼침 상태 (결정 069)
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.diagnosticsAppState,
                            style: context.appTextStyles.headline,
                          ),
                          Text(
                            context.keepAllText(l10n.diagnosticsAppStateHint),
                            style: context.appTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: SelectableText(
                  widget.appState,
                  style: context.appTextStyles.code,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
