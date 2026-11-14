import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import 'onboarding_illustration.dart';

/// 준비 완료 화면 (#376): 그림이 튀어나오며 등장 > 제목·설명·버튼이 차례로 > 첫 장소 정하기
class OnboardingReadyView extends StatefulWidget {
  const OnboardingReadyView({
    required this.onAddFirstPlace,
    required this.onLater,
    this.extra,
    super.key,
  });

  /// 첫 장소 등록 화면으로 이어감
  final VoidCallback onAddFirstPlace;

  /// 홈으로
  final VoidCallback onLater;

  /// 버튼 위에 둘 카드 (iOS 알림·진동 시험, #237). null 이면 없음
  final Widget? extra;

  @override
  State<OnboardingReadyView> createState() => _OnboardingReadyViewState();
}

class _OnboardingReadyViewState extends State<OnboardingReadyView>
    with SingleTickerProviderStateMixin {
  // 등장 연출 전체 시간 · 그림 크기 (dp)
  static const Duration _entranceDuration = Duration(milliseconds: 1100);
  static const double _illustrationSize = 240;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _entranceDuration,
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// 구간 [begin, end] 에서 0 > 1 로 움직이는 애니메이션 (차례로 등장)
  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final extra = widget.extra;
    final illustrationIn = _interval(0, 0.55, Curves.easeOutBack);
    final textIn = _interval(0.35, 0.75, Curves.easeOutCubic);
    final buttonsIn = _interval(0.6, 1, Curves.easeOutCubic);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(illustrationIn),
            child: FadeTransition(
              opacity: illustrationIn,
              child: const Center(
                child: OnboardingIllustrationView(
                  illustration: OnboardingIllustration.ready,
                  size: _illustrationSize,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RiseIn(
            animation: textIn,
            child: Column(
              children: [
                Text(
                  l10n.onboardingReadyTitle,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.keepAllText(l10n.onboardingReadyBody),
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.body.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _RiseIn(
            animation: buttonsIn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (extra != null) ...[
                  extra,
                  const SizedBox(height: AppSpacing.sm),
                ],
                FilledButton(
                  onPressed: widget.onAddFirstPlace,
                  child: Text(l10n.onboardingReadyAddPlace),
                ),
                TextButton(
                  onPressed: widget.onLater,
                  child: Text(l10n.onboardingReadyLater),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래에서 살짝 올라오며 나타남
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}
