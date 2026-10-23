import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/ios_vibration_check_state.dart';
import 'ios_settings_mockup.dart';

/// 진동 점검 단계 안내 1장 (이슈 #301)
///
/// iOS 설정 화면 모양을 그대로 그려 어느 줄을 바꿀지 보이게 한다 — 햅틱·손쉬운 사용·집중 모드는
/// 바로 가는 공개 경로가 없어(비공개 URL 은 심사 거절) 글과 그림으로 안내
class IosSettingsGuidePage extends StatelessWidget {
  const IosSettingsGuidePage({
    required this.step,
    required this.onOpenAppSettings,
    required this.onChanged,
    required this.onGiveUp,
    super.key,
  });

  final IosVibrationCheckStep step;
  final VoidCallback onOpenAppSettings;

  /// 바꿨어요 (다음 단계) · 마지막 단계는 다시 시험
  final VoidCallback onChanged;
  final VoidCallback onGiveUp;

  bool get _isLastStep => step == IosVibrationCheckStep.guideFocusMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.appColors;
    final (eyebrow, title, path, mockup, hint) = switch (step) {
      IosVibrationCheckStep.guideAccessibilityVibration => (
        l10n.vibrationCheckGuideAccessibilityEyebrow,
        l10n.vibrationCheckGuideAccessibilityTitle,
        [
          l10n.iosSettingsRoot,
          l10n.iosSettingsAccessibility,
          l10n.iosSettingsTouch,
        ],
        IosSettingsMockup(
          sectionTitle: l10n.iosSettingsTouch,
          rows: [
            IosSettingsMockupRow.toggle(l10n.iosSettingsTapToWake),
            IosSettingsMockupRow.toggle(l10n.iosSettingsShakeToUndo),
            IosSettingsMockupRow.toggle(
              l10n.iosSettingsVibration,
              isTarget: true,
            ),
          ],
        ),
        l10n.vibrationCheckGuideAccessibilityHint,
      ),
      IosVibrationCheckStep.guideFocusMode => (
        l10n.vibrationCheckGuideFocusEyebrow,
        l10n.vibrationCheckGuideFocusTitle,
        [
          l10n.iosSettingsRoot,
          l10n.iosSettingsFocus,
          l10n.iosSettingsFocusMode,
        ],
        IosSettingsMockup(
          sectionTitle: l10n.iosSettingsFocusMode,
          rows: [
            IosSettingsMockupRow.navigation(
              l10n.iosSettingsFocusAllowApp,
              isTarget: true,
            ),
          ],
        ),
        l10n.vibrationCheckGuideFocusHint,
      ),
      _ => (
        l10n.vibrationCheckGuideHapticsEyebrow,
        l10n.vibrationCheckGuideHapticsTitle,
        [
          l10n.iosSettingsRoot,
          l10n.iosSettingsSoundsAndHaptics,
          l10n.iosSettingsHaptics,
        ],
        IosSettingsMockup(
          sectionTitle: l10n.iosSettingsHaptics,
          rows: [
            IosSettingsMockupRow.choice(
              l10n.iosSettingsHapticsAlways,
              isTarget: true,
            ),
            IosSettingsMockupRow.choice(l10n.iosSettingsHapticsSilentOnly),
            IosSettingsMockupRow.choice(l10n.iosSettingsHapticsNotInSilent),
            IosSettingsMockupRow.choice(l10n.iosSettingsHapticsNever),
          ],
        ),
        null,
      ),
    };

    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.tune_outlined,
      title: title,
      headerTrailing: _GuideProgress(position: step.guidePosition ?? 1),
      description: eyebrow,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosSettingsPath(segments: path),
          const SizedBox(height: AppSpacing.sm),
          mockup,
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.keepAllText(hint),
              style: context.appTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // 설정 열기는 이 앱 페이지까지만 — 거기서 첫 화면으로 가는 법을 함께 적는다
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outlined,
                size: AppIconSize.inline,
                color: palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.keepAllText(l10n.vibrationCheckGuideOpenSettingsHint),
                  style: context.appTextStyles.caption,
                ),
              ),
            ],
          ),
          if (_isLastStep)
            TextButton(
              onPressed: onGiveUp,
              child: Text(l10n.vibrationCheckGuideStillNot),
            ),
        ],
      ),
      primaryAction: FilledButton(
        onPressed: onChanged,
        child: Text(
          _isLastStep
              ? l10n.vibrationCheckTryAgain
              : l10n.vibrationCheckGuideChanged,
        ),
      ),
      secondaryAction: OutlinedButton(
        onPressed: onOpenAppSettings,
        child: Text(l10n.vibrationCheckOpenSettings),
      ),
    );
  }
}

/// 제목 줄 오른쪽 단계 표시 (막대 3개 + 1/3)
class _GuideProgress extends StatelessWidget {
  const _GuideProgress({required this.position});

  final int position;

  /// 단계 막대 한 칸 크기
  static const double _barWidth = 14;
  static const double _barHeight = 4;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (
          var index = 1;
          index <= IosVibrationCheckStep.guideStepCount;
          index++
        )
          Container(
            width: _barWidth,
            height: _barHeight,
            margin: const EdgeInsets.only(left: _barHeight),
            decoration: BoxDecoration(
              color: index <= position ? palette.accent : palette.separator,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$position/${IosVibrationCheckStep.guideStepCount}',
          style: context.appTextStyles.caption.copyWith(color: palette.accent),
        ),
      ],
    );
  }
}
