part of 'onboarding_checklist_view.dart';

// 체크리스트 부품: 진행 링, 단계 안내 줄, 장면 설명, 선택 묶음

/// 진행 링: 값이 바뀌면 부드럽게 참
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.done, required this.total});

  final int done;
  final int total;

  // 링 지름 · 두께 (dp)
  static const double _diameter = 48;
  static const double _strokeWidth = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: total == 0 ? 0 : done / total),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox.square(
        dimension: _diameter,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            trackColor: colors.elevated,
            barColor: colors.accent,
            strokeWidth: _strokeWidth,
          ),
          child: Center(
            child: Text(
              '$done/$total',
              style: context.appTextStyles.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.barColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color barColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = trackColor);
    if (progress <= 0) return;
    // 12시 방향에서 시계 방향으로
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = barColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.barColor != barColor ||
      oldDelegate.trackColor != trackColor;
}

/// 단계별 안내 한 줄 — 바뀔 때 위로 밀려 올라가며 교체
class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Row(
        key: ValueKey(text),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.arrow_forward_rounded,
            size: AppIconSize.inline,
            color: colors.accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              context.keepAllText(text),
              style: context.appTextStyles.body.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneCaption extends StatelessWidget {
  const _SceneCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    child: Text(
      context.keepAllText(text),
      key: ValueKey(text),
      textAlign: TextAlign.center,
      style: context.appTextStyles.caption,
    ),
  );
}

/// 선택 권한 묶음 (Android): 접혀 있다가 누르면 펼쳐짐
class _OptionalSection extends StatefulWidget {
  const _OptionalSection({required this.rows});

  final List<Widget> rows;

  @override
  State<_OptionalSection> createState() => _OptionalSectionState();
}

class _OptionalSectionState extends State<_OptionalSection> {
  /// 펼쳤는가 (화면 안 접기 상태라 저장하지 않음)
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.onboardingOptionalHeader,
                    style: context.appTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: _isExpanded
              ? Column(children: widget.rows)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// 위치는 기기에만 남는다는 한 줄 (자물쇠)
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outlined,
          size: AppIconSize.inline,
          color: context.appColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            context.keepAllText(context.l10n.permissionLocalOnlyFootnote),
            style: context.appTextStyles.caption,
          ),
        ),
      ],
    ),
  );
}
