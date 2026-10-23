import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/ios_vibration_check_state.dart';

/// ② 시험 알림까지 남은 초 — 링이 줄어들며 숫자가 내려간다
class VibrationTestCountdownRing extends StatelessWidget {
  const VibrationTestCountdownRing({super.key});

  static const double _diameter = 140;
  static const double _strokeWidth = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(seconds: testNotificationDelaySeconds),
      builder: (context, remainingFraction, _) {
        final secondsLeft = (remainingFraction * testNotificationDelaySeconds)
            .ceil();
        return SizedBox.square(
          dimension: _diameter,
          child: CustomPaint(
            painter: _RingPainter(
              remainingFraction: remainingFraction,
              trackColor: palette.elevated,
              progressColor: palette.accent,
              strokeWidth: _strokeWidth,
            ),
            child: Center(
              child: secondsLeft > 0
                  ? Text(
                      '$secondsLeft',
                      style: context.appTextStyles.displayLarge,
                    )
                  : Icon(
                      Icons.vibration,
                      size: AppIconSize.hero,
                      color: palette.accent,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.remainingFraction,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double remainingFraction;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    // 12시 방향부터 남은 만큼
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * remainingFraction,
      false,
      paint..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.remainingFraction != remainingFraction ||
      oldDelegate.progressColor != progressColor;
}
