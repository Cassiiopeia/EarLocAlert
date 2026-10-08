import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_feedback.dart';
import 'vibration_check_provider.dart';

/// 진동 시험 흐름 (이슈 #237) — 떨기 → "느껴졌나요?" → 아니요면 안내 시트.
///
/// 설정 앱을 여는 일은 이 feature 가 모른다 — [onOpenSettings] 로 받는다
/// (docs/02-ARCHITECTURE.md 규칙 1).
///
/// **앱 수명의 컨테이너를 붙잡는다.** 답을 기다리는 동안 부른 화면이 사라져도
/// 답은 저장돼야 한다 — 화면의 ref 는 그때 이미 못 쓴다 (이슈 #122 와 같은 이유).
Future<void> runVibrationCheck(
  BuildContext context, {
  required String trigger,
  required Future<void> Function() onOpenSettings,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final check = container.read(vibrationCheckProvider.notifier);

  await check.fire(trigger: trigger);
  if (!context.mounted) return;

  final felt = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.vibrationTestQuestion),
      content: Text(
        dialogContext.keepAllText(dialogContext.l10n.vibrationTestQuestionBody),
        style: AppTypography.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.vibrationTestNo),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.vibrationTestYes),
        ),
      ],
    ),
  );

  if (felt == null) {
    // 답하지 않고 닫았다 — 지난 답을 덮지 않는다
    Diagnostics.log('vibration', 'test answer skipped trigger=$trigger');
    return;
  }
  await check.answer(felt: felt);
  if (!context.mounted) return;

  if (felt) {
    context.showToast(context.l10n.vibrationTestFeltToast);
  } else {
    await showVibrationGuideSheet(context, onOpenSettings: onOpenSettings);
  }
}

/// 진동이 느껴지지 않을 때의 안내 시트 (이슈 #237)
///
/// 설정 앱은 이 앱의 페이지까지만 열 수 있다 — 손쉬운 사용·사운드 및 햅틱으로
/// 바로 보내는 공개 경로가 없다. 그래서 어디서 무엇을 켜는지를 글로 적는다.
Future<void> showVibrationGuideSheet(
  BuildContext context, {
  required Future<void> Function() onOpenSettings,
}) {
  Diagnostics.log('vibration', 'guide opened');
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _VibrationGuideSheet(
      onOpenSettings: () {
        Diagnostics.log('vibration', 'guide settings_opened');
        Navigator.of(sheetContext).pop();
        unawaited(onOpenSettings());
      },
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _VibrationGuideSheet extends StatelessWidget {
  const _VibrationGuideSheet({
    required this.onOpenSettings,
    required this.onClose,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.vibrationGuideStepAccessibility,
      l10n.vibrationGuideStepHaptics,
      l10n.vibrationGuideStepSystemHaptics,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.keepAllText(l10n.vibrationGuideTitle),
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.keepAllText(l10n.vibrationGuideBody),
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            // 순서대로 확인하면 되게 번호를 붙인다 — 첫 항목이 꺼져 있으면 나머지와
            // 무관하게 모든 진동이 멈춘다
            for (final (index, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        context.keepAllText(step),
                        style: AppTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outlined,
                  size: AppIconSize.inline,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    context.keepAllText(l10n.vibrationGuideHint),
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onOpenSettings,
              child: Text(l10n.vibrationGuideOpenSettings),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onClose,
              child: Text(l10n.vibrationGuideClose),
            ),
          ],
        ),
      ),
    );
  }
}
