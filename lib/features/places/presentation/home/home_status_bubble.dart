part of '../place_map_home_screen.dart';

// 상단 알약을 누르면 장소 시트 위로 떠오르는 상태 물방울 (이슈 #306)

/// 상태 물방울: 감시 상태 + 이어폰 상태 + (고장이면) 해결 버튼
///
/// 진입 > 가로가 먼저 퍼지며 시트 위에서 솟음 / 퇴장 > 짧게 가라앉음
/// 바깥을 누르면 닫힌다 — 모달이 아니라 지도 위에 얹힌 팝업이다
class _StatusBubble extends StatefulWidget {
  const _StatusBubble({
    required this.isOpen,
    required this.sheetFraction,
    required this.isMonitoring,
    required this.isBroken,
    required this.isChecking,
    required this.isHeadphoneConnected,
    required this.onDismiss,
    this.onFixMonitoring,
  });

  final bool isOpen;

  /// 장소 시트가 차지한 화면 비율 — 물방울이 시트 바로 위에 선다
  final double sheetFraction;
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
  static const _riseOffsetPixels = 28.0;
  static const _hiddenScale = 0.55;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.isOpen ? 1 : 0,
  );

  // 가로는 살짝 넘쳤다 돌아오고(물방울이 퍼지는 느낌), 세로는 부드럽게 오른다
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
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  MediaQuery.sizeOf(context).height * widget.sheetFraction +
                      AppSpacing.sm,
                ),
                child: Opacity(
                  opacity: _fade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - _scaleY.value) * _riseOffsetPixels),
                    child: Transform.scale(
                      alignment: Alignment.bottomCenter,
                      scaleX: _hiddenScale + (1 - _hiddenScale) * _scaleX.value,
                      scaleY: _hiddenScale + (1 - _hiddenScale) * _scaleY.value,
                      child: bubble,
                    ),
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.elevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.separator),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.homeStatusSheetTitle,
              style: context.appTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
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
    );
  }
}

/// 아이콘 + 제목 + 한 줄 설명
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

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.standard, color: color),
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
