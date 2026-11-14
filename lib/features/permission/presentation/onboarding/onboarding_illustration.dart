import 'package:flutter/material.dart';

/// 온보딩 그림 4장 (#376) — 에셋 경로 단일 원본
enum OnboardingIllustration {
  location('assets/images/onboarding/location.png'),
  background('assets/images/onboarding/background.png'),
  notification('assets/images/onboarding/notification.png'),
  ready('assets/images/onboarding/ready.png');

  const OnboardingIllustration(this.assetPath);

  final String assetPath;
}

/// 온보딩 그림: 바뀔 때 페이드·확대로 교체 + 위아래로 천천히 떠 있는 움직임
class OnboardingIllustrationView extends StatefulWidget {
  const OnboardingIllustrationView({
    required this.illustration,
    required this.size,
    super.key,
  });

  final OnboardingIllustration illustration;

  /// 그림 한 변 (dp)
  final double size;

  @override
  State<OnboardingIllustrationView> createState() =>
      _OnboardingIllustrationViewState();
}

class _OnboardingIllustrationViewState extends State<OnboardingIllustrationView>
    with SingleTickerProviderStateMixin {
  // 떠 있는 움직임 한 주기 · 높이 (dp)
  static const Duration _floatPeriod = Duration(milliseconds: 2800);
  static const double _floatHeight = 6;
  // 그림 교체 시간
  static const Duration _switchDuration = Duration(milliseconds: 450);

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: _floatPeriod,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 접근성 설정의 '움직임 줄이기'면 떠 있는 움직임을 멈춤
    final shouldReduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedSwitcher(
        duration: _switchDuration,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: AnimatedBuilder(
          key: ValueKey(widget.illustration),
          animation: _float,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              shouldReduceMotion
                  ? 0
                  : -_floatHeight * Curves.easeInOut.transform(_float.value),
            ),
            child: child,
          ),
          child: Image.asset(
            widget.illustration.assetPath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            // 그림은 장식 — 의미는 옆 문구가 전달
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
