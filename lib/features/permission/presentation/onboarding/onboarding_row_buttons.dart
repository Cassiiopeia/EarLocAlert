part of 'onboarding_permission_row.dart';

// 줄 오른쪽 버튼 부품: 허용 버튼(맥박), 허용됨 표시(체크 그리기)

/// 허용 버튼 — 다음 할 줄이면 민트 채움 + 은은한 맥박
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.isHighlighted,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isHighlighted;
  final VoidCallback onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  // 맥박 한 주기 · 퍼지는 그림자 최대 폭 (dp)
  static const Duration _pulsePeriod = Duration(milliseconds: 1600);
  static const double _pulseSpread = 7;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulsePeriod,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_ActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.isHighlighted) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final background = widget.isHighlighted ? colors.accent : colors.elevated;
    final foreground = widget.isHighlighted
        ? colors.onAccent
        : colors.textPrimary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small / 1.5),
          boxShadow: [
            if (widget.isHighlighted)
              BoxShadow(
                color: colors.accent.withValues(
                  alpha: 0.45 * (1 - _pulse.value),
                ),
                spreadRadius: _pulseSpread * _pulse.value,
              ),
          ],
        ),
        child: child,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.small / 1.5),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(AppRadius.small / 1.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm - AppSpacing.xs / 2,
              vertical: AppSpacing.xs + AppSpacing.xs / 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: context.appTextStyles.caption.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.inline,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ✓ 허용됨 — 체크 표시가 왼쪽부터 그려짐
class _GrantedLabel extends StatelessWidget {
  const _GrantedLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs + AppSpacing.xs / 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Icon(
                  Icons.check_rounded,
                  size: AppIconSize.inline,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs / 2),
          Text(
            label,
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
