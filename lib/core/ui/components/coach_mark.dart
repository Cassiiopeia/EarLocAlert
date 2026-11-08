import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../foundation/app_color_palette.dart';
import '../foundation/app_spacing.dart';

/// 코치마크 한 단계: 비출 대상 위젯 + 제목 + 설명
class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });

  /// 비출 위젯에 붙인 키 (화면에 그려져 있어야 한다)
  final GlobalKey targetKey;
  final String title;
  final String description;
}

/// 코치마크 표시: 대상만 밝게 비추고 말풍선으로 설명 (끝나거나 건너뛰면 완료)
///
/// 단계 이동 > 구멍이 다음 대상으로 미끄러지고 말풍선이 페이드·슬라이드로 바뀐다.
/// 키가 아직 그려지지 않은 단계는 건너뛴다. 남은 단계가 없으면 아무것도 띄우지 않는다.
Future<void> showCoachMarks(
  BuildContext context, {
  required List<CoachMarkStep> steps,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CoachMarkOverlay(
      steps: steps,
      onFinished: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// 비춘 대상 둘레 여백
const double _targetPadding = AppSpacing.xs;

/// 말풍선 최대 폭
const double _bubbleMaxWidth = 360;

/// 단계 이동 애니메이션 길이
const Duration _stepDuration = Duration(milliseconds: 420);

/// 테두리 링이 숨 쉬는 주기
const Duration _pulseDuration = Duration(milliseconds: 1400);

/// 말풍선 버튼 최소 크기 — 테마 기본값(가로 전체)은 Row 안에서 폭 계산이 깨져 버튼이 사라진다
const Size _actionButtonMinimumSize = Size(96, 44);

class _CoachMarkOverlay extends StatefulWidget {
  const _CoachMarkOverlay({required this.steps, required this.onFinished});

  final List<CoachMarkStep> steps;
  final VoidCallback onFinished;

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _stepController = AnimationController(
    vsync: this,
    duration: _stepDuration,
  );
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );

  /// 지금 보여 주는 단계의 인덱스 (그려진 대상이 있는 단계만)
  late List<int> _visibleStepIndexes;
  int _position = 0;
  Rect? _fromRect;
  Rect? _toRect;

  bool get _isLast => _position >= _visibleStepIndexes.length - 1;

  @override
  void initState() {
    super.initState();
    _visibleStepIndexes = [
      for (var i = 0; i < widget.steps.length; i++)
        if (_rectOf(widget.steps[i]) != null) i,
    ];
    if (_visibleStepIndexes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
      return;
    }
    _toRect = _rectOf(_currentStep);
    // 첫 단계는 대상 가운데에서 구멍이 퍼지며 나타난다
    _fromRect = Rect.fromCenter(center: _toRect!.center, width: 0, height: 0);
    _stepController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기 설정이면 숨쉬기를 돌리지 않는다
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _stepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  CoachMarkStep get _currentStep =>
      widget.steps[_visibleStepIndexes[_position]];

  /// 대상의 화면 좌표 영역 (그려지지 않았으면 null)
  Rect? _rectOf(CoachMarkStep step) {
    final box = step.targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return (box.localToGlobal(Offset.zero) & box.size).inflate(_targetPadding);
  }

  void _advance() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    final next = _position + 1;
    final nextRect = _rectOf(widget.steps[_visibleStepIndexes[next]]);
    setState(() {
      _fromRect = _currentRect;
      _toRect = nextRect ?? _toRect;
      _position = next;
    });
    _stepController.forward(from: 0);
  }

  Rect get _currentRect => Rect.lerp(
    _fromRect,
    _toRect,
    Curves.easeInOutCubic.transform(_stepController.value),
  )!;

  @override
  Widget build(BuildContext context) {
    if (_visibleStepIndexes.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;
    final screen = MediaQuery.sizeOf(context);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_stepController, _pulseController]),
        builder: (context, _) {
          final rect = _currentRect;
          final enter = Curves.easeOutCubic.transform(_stepController.value);
          final isBelow = rect.center.dy < screen.height / 2;
          return Stack(
            children: [
              // 바깥 탭 > 다음 단계 (지도로는 넘기지 않음 — 움직이면 비춘 자리가 어긋난다)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _advance,
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      hole: rect,
                      scrim: colors.scrim,
                      ring: colors.accent,
                      pulse: _pulseController.value,
                    ),
                  ),
                ),
              ),
              _bubble(
                context,
                rect: rect,
                isBelow: isBelow,
                enter: enter,
                screen: screen,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bubble(
    BuildContext context, {
    required Rect rect,
    required bool isBelow,
    required double enter,
    required Size screen,
  }) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final step = _currentStep;
    final width = (screen.width - AppSpacing.sm * 2).clamp(
      0.0,
      _bubbleMaxWidth,
    );
    final left = (rect.center.dx - width / 2).clamp(
      AppSpacing.sm,
      screen.width - width - AppSpacing.sm,
    );
    // 대상이 위쪽이면 아래에, 아래쪽이면 위에 띄운다 (페이드 + 8px 슬라이드)
    final slide = (1 - enter) * AppSpacing.xs * (isBelow ? 1 : -1);

    final card = Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.coachMarkStepCounter(
              _position + 1,
              _visibleStepIndexes.length,
            ),
            style: context.appTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(step.title, style: context.appTextStyles.headline),
          const SizedBox(height: AppSpacing.xs),
          Text(step.description, style: context.appTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // 건너뛰기는 작은 회색 글자 — 주 버튼(다음)과 헷갈려 누르지 않게
              if (!_isLast)
                TextButton(
                  onPressed: widget.onFinished,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    textStyle: context.appTextStyles.caption,
                  ),
                  child: Text(l10n.coachMarkSkip),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _advance,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  minimumSize: _actionButtonMinimumSize,
                ),
                child: Text(_isLast ? l10n.coachMarkDone : l10n.coachMarkNext),
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(
      left: left,
      top: isBelow ? rect.bottom + AppSpacing.sm : null,
      bottom: isBelow ? null : screen.height - rect.top + AppSpacing.sm,
      child: Opacity(
        opacity: enter,
        child: Transform.translate(offset: Offset(0, slide), child: card),
      ),
    );
  }
}

/// 어두운 막 + 대상 구멍 + 숨 쉬는 테두리 링
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.scrim,
    required this.ring,
    required this.pulse,
  });

  final Rect hole;
  final Color scrim;
  final Color ring;

  /// 0~1 — 링이 커졌다 작아지는 정도
  final double pulse;

  /// 구멍 모서리: 작은 대상(버튼·알약)은 원/캡슐, 큰 대상(시트)은 카드 반경
  RRect _rounded(Rect rect) {
    final radius = rect.shortestSide <= 72
        ? rect.shortestSide / 2
        : AppRadius.card;
    return RRect.fromRectAndRadius(rect, Radius.circular(radius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final whole = Path()..addRect(Offset.zero & size);
    final cutout = Path()..addRRect(_rounded(hole));
    canvas.drawPath(
      Path.combine(PathOperation.difference, whole, cutout),
      Paint()..color = scrim,
    );
    // 링: 커질수록 옅어진다
    final ringRect = hole.inflate(pulse * AppSpacing.xs);
    canvas.drawRRect(
      _rounded(ringRect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: 1 - pulse * 0.6),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse || old.scrim != scrim;
}
