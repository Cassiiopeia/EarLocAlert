import 'package:flutter/material.dart';

import '../../../../core/text/keep_all.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';

part 'onboarding_row_buttons.dart';

/// 권한 한 줄의 상태 4가지
enum OnboardingRowState {
  /// 아직 안 켬 (요청 가능)
  pending,

  /// 다음에 할 줄 — 민트 강조 + 버튼 깜빡임
  next,

  /// 허용됨 — 체크가 그려지며 바뀜
  granted,

  /// 앱에서 다시 물을 수 없음 — 설정 열기
  blocked,
}

/// 권한 한 줄: 아이콘 · 이름(+설정에서 표시) · 이유 · 오른쪽 버튼 (#376, 참고: 터닝)
class OnboardingPermissionRow extends StatelessWidget {
  const OnboardingPermissionRow({
    required this.icon,
    required this.title,
    required this.reason,
    required this.rowState,
    required this.onPressed,
    this.isOpenedInSettings = false,
    super.key,
  });

  final IconData icon;
  final String title;

  /// 왜 필요한지 한 줄
  final String reason;
  final OnboardingRowState rowState;
  final VoidCallback onPressed;

  /// 시스템 창이 아니라 설정 화면에서 켜는 권한인가 (작은 표시를 붙임)
  final bool isOpenedInSettings;

  // 강조 줄 민트 섞는 비율 · 바뀌는 시간
  static const double _highlightTintRatio = 0.12;
  static const Duration _changeDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isNext = rowState == OnboardingRowState.next;
    final isGranted = rowState == OnboardingRowState.granted;
    return AnimatedContainer(
      duration: _changeDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm - AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: isNext
            ? Color.lerp(colors.background, colors.accent, _highlightTintRatio)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIcon(icon: icon, isGranted: isGranted),
          const SizedBox(width: AppSpacing.sm - AppSpacing.xs / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs / 2,
                  children: [
                    Text(
                      title,
                      style: context.appTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isOpenedInSettings && !isGranted)
                      _SmallTag(label: context.l10n.onboardingTagSettings),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs / 4),
                Text(
                  context.keepAllText(reason),
                  style: context.appTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _RowAction(rowState: rowState, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.isGranted});

  final IconData icon;
  final bool isGranted;

  // 아이콘 칸 한 변 (dp)
  static const double _tileSize = 36;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: isGranted
            ? colors.accent.withValues(alpha: 0.18)
            : colors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.small / 1.5),
      ),
      child: Icon(
        icon,
        size: AppIconSize.inline,
        color: isGranted ? colors.accent : colors.textPrimary,
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(AppSpacing.xs / 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs / 1.5,
          vertical: AppSpacing.xs / 4,
        ),
        child: Text(
          label,
          style: context.appTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 버튼: 허용 › / 설정 열기 › / ✓ 허용됨 (체크가 그려지며 튀어나옴)
class _RowAction extends StatelessWidget {
  const _RowAction({required this.rowState, required this.onPressed});

  final OnboardingRowState rowState;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: switch (rowState) {
        OnboardingRowState.granted => _GrantedLabel(
          key: const ValueKey('granted'),
          label: l10n.onboardingAllowed,
        ),
        OnboardingRowState.blocked => _ActionButton(
          key: const ValueKey('blocked'),
          label: l10n.onboardingOpenSettings,
          isHighlighted: true,
          onPressed: onPressed,
        ),
        OnboardingRowState.next || OnboardingRowState.pending => _ActionButton(
          key: ValueKey(rowState),
          label: l10n.onboardingAllow,
          isHighlighted: rowState == OnboardingRowState.next,
          onPressed: onPressed,
        ),
      },
    );
  }
}
