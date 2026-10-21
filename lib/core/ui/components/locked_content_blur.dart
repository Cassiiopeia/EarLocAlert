import 'dart:ui';

import 'package:flutter/material.dart';

import '../../text/keep_all.dart';
import '../foundation/app_color_palette.dart';
import '../foundation/app_spacing.dart';

/// 잠긴 기능 묶음: 흐린 미리보기 + 가운데 설명·열기 버튼 (#294)
/// 영역 어디를 눌러도 `onUnlock`. 흐린 항목 자체는 눌리지 않음. 자물쇠 아이콘 없음
class LockedContentBlur extends StatelessWidget {
  const LockedContentBlur({
    required this.child,
    required this.caption,
    required this.actionLabel,
    required this.onUnlock,
    super.key,
  });

  /// 흐리게 보일 실제 UI (눌리지 않음)
  final Widget child;
  final String caption;
  final String actionLabel;
  final VoidCallback onUnlock;

  // 흐림 세기 — 글자 모양은 보이되 읽히지 않는 정도
  static const double _blurSigma = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: '$caption, $actionLabel',
      // 하위 의미를 지우므로 누르기 동작을 여기서 다시 준다 (화면 낭독기)
      onTap: onUnlock,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onUnlock,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Stack(
            children: [
              // 흐린 미리보기 (입력 차단)
              IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _blurSigma,
                    sigmaY: _blurSigma,
                  ),
                  child: Opacity(opacity: 0.7, child: child),
                ),
              ),
              // 위아래로 옅어지는 덮개 > 가운데 설명·버튼이 떠 보이게
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.background.withValues(alpha: 0.15),
                        colors.background.withValues(alpha: 0.55),
                        colors.background.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.keepAllText(caption),
                          style: context.appTextStyles.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        FilledButton(
                          onPressed: onUnlock,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.onAccent,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          child: Text(actionLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
