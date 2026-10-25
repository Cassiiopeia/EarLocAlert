part of '../place_map_home_screen.dart';

// 상단 알약을 누르면 알약 밑으로 흘러내리듯 펼쳐지는 상태 물방울 (이슈 #306)

/// 상태 물방울: 감시 상태 + 이어폰 상태 + (고장이면) 해결 버튼
///
/// 진입 > 알약 왼쪽 끝을 기점으로 아래로 늘어나며 펼침 / 퇴장 > 알약으로 되감김
/// 바깥을 누르면 닫힌다 — 모달이 아니라 지도 위에 얹힌 팝업이다
class _StatusBubble extends StatefulWidget {
  const _StatusBubble({
    required this.isOpen,
    required this.isMonitoring,
    required this.isBroken,
    required this.isChecking,
    required this.isHeadphoneConnected,
    required this.onDismiss,
    this.onFixMonitoring,
  });

  final bool isOpen;

  final bool isMonitoring;
  final bool isBroken;
  final bool isChecking;
  final bool isHeadphoneConnected;
  final VoidCallback onDismiss;

  /// 고장일 때만 쓴다 — 권한 화면으로 보내는 해결 경로
  final VoidCallback? onFixMonitoring;

  @override
  State<_StatusBubble> createState() => _StatusBubbleState();
}

class _StatusBubbleState extends State<_StatusBubble>
    with SingleTickerProviderStateMixin {
  static const _hiddenScale = 0.25;

  // 유리 질감: 뒤 지도를 흐리게 비추는 정도와 카드 불투명도
  static const _glassBlurSigma = 24.0;
  static const _glassOpacity = 0.94;

  // 알약 높이 + 위 여백 + 알약과 물방울 사이 틈
  static const _pillGap = AppSpacing.xs;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.isOpen ? 1 : 0,
  );

  // 가로는 살짝 넘쳤다 돌아오고(물방울이 퍼지는 느낌), 세로는 부드럽게 흘러내린다
  late final Animation<double> _scaleX = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _scaleY = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutQuint,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
    reverseCurve: Curves.easeIn,
  );

  @override
  void didUpdateWidget(_StatusBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) return;
    if (widget.isOpen) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, bubble) {
        // 완전히 닫히면 터치도 그리기도 하지 않는다
        if (_controller.isDismissed) return const SizedBox.shrink();
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                // 알약 바로 밑 — 알약과 같은 왼쪽 선에서 시작한다
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  MediaQuery.paddingOf(context).top +
                      AppSpacing.sm +
                      AppControlSize.floating +
                      _pillGap,
                  AppSpacing.sm,
                  0,
                ),
                child: Opacity(
                  opacity: _fade.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scaleX: _hiddenScale + (1 - _hiddenScale) * _scaleX.value,
                    scaleY: _hiddenScale + (1 - _hiddenScale) * _scaleY.value,
                    child: bubble,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      // 카드는 애니메이션마다 다시 만들지 않는다
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = context.l10n;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final colors = context.appColors;

    final monitoringColor = widget.isMonitoring
        ? semantic.statusActive
        : widget.isBroken
        ? semantic.statusInactive
        : colors.textSecondary;

    // 카드 안을 누를 때는 닫지 않는다 — 바깥 탭만 닫는다
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _glassBlurSigma,
            sigmaY: _glassBlurSigma,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: _glassOpacity),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeStatusSheetTitle,
                  style: context.appTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusBubbleRow(
                  icon: widget.isMonitoring
                      ? Icons.radar_outlined
                      : widget.isBroken
                      ? Icons.warning_amber_outlined
                      : widget.isChecking
                      ? Icons.hourglass_empty_outlined
                      : Icons.pause_circle_outlined,
                  color: monitoringColor,
                  title: widget.isMonitoring
                      ? l10n.placeHomeStatusWatching
                      : widget.isBroken
                      ? l10n.placeHomeStatusOff
                      : widget.isChecking
                      ? l10n.placeHomeStatusChecking
                      : l10n.placeHomeStatusIdle,
                  description: widget.isMonitoring
                      ? l10n.homeStatusWatchingDescription
                      : widget.isBroken
                      ? l10n.homeStatusOffDescription
                      : widget.isChecking
                      ? l10n.homeStatusCheckingDescription
                      : l10n.homeStatusIdleDescription,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusBubbleRow(
                  icon: widget.isHeadphoneConnected
                      ? Icons.headphones_outlined
                      : Icons.vibration_outlined,
                  color: widget.isHeadphoneConnected
                      ? semantic.audioBluetooth
                      : colors.textSecondary,
                  title: widget.isHeadphoneConnected
                      ? l10n.placeHomeAudioHeadphones
                      : l10n.placeHomeAudioVibrationOnly,
                  description: widget.isHeadphoneConnected
                      ? l10n.homeAudioHeadphonesDescription
                      : l10n.homeAudioVibrationOnlyDescription,
                ),
                if (widget.isBroken && widget.onFixMonitoring != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: widget.onFixMonitoring,
                    child: Text(l10n.homeStatusFixButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이콘 배지 + 제목 + 한 줄 설명
class _StatusBubbleRow extends StatelessWidget {
  const _StatusBubbleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  static const double _badgeDiameter = 40;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상태 색을 옅게 깐 원 안에 아이콘 — 색만이 아니라 모양으로도 구분
        Container(
          width: _badgeDiameter,
          height: _badgeDiameter,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppIconSize.control, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.appTextStyles.headline.copyWith(color: color),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                context.keepAllText(description),
                style: context.appTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
