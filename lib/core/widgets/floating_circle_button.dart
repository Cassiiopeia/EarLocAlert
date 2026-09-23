import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'hit_slop.dart';

/// 지도 위에 떠 있는 원형 버튼 (docs/06-UX.md "지도 위에 떠 있는 조작 요소")
///
/// **크기·모양·그림자·탭 범위를 한 곳에서 정한다** (디자인 리뷰 #155).
/// 예전에는 설정은 40 원, 내 위치는 40 둥근 사각형, 장소 추가는 56 둥근
/// 사각형에 그림자까지 — 떠 있는 버튼 셋이 모양 둘, 크기 둘이었다.
///
/// - 모양은 원 하나. 상단 알약(캡슐)과 결이 맞는다
/// - 그림자를 쓰지 않는다 — 다크에서는 보이지 않고, 층은 배경 명도로 가른다
/// - 보이는 원보다 [slop] 만큼 넓게 눌린다 ([HitSlop])
class FloatingCircleButton extends StatelessWidget {
  const FloatingCircleButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = AppControlSize.floating,
    this.background = AppColors.bgSurface,
    this.foreground = AppColors.textPrimary,
    this.slop = const EdgeInsets.all(AppSpacing.xs),
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// 스크린리더가 읽는 이름 — 아이콘만으로는 무엇인지 알 수 없다
  final String semanticLabel;

  /// 보이는 원의 지름. 보조는 [AppControlSize.floating], 주 동작은
  /// [AppControlSize.primary]
  final double size;

  final Color background;
  final Color foreground;

  /// 보이는 원 바깥으로 탭을 더 받는 폭
  final EdgeInsets slop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: HitSlop(
        onTap: onPressed,
        padding: slop,
        child: SizedBox.square(
          dimension: size,
          child: Material(
            color: background,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(icon, size: AppIconSize.standard, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
