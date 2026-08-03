import 'package:flutter/material.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 해제 완료 화면 (docs/07-MONETIZATION.md)
///
/// **전면광고가 들어갈 자리다.** 알림 화면이 아니라 여기다 —
/// 해제 버튼을 누른 *다음* 화면이어야 우발적 클릭 유도가 아니다.
///
/// 광고 통합은 별도 이슈다. 다만 자리를 여기로 확정해두면 나중에
/// 알림 화면에 광고를 넣는 실수를 하지 않는다.
class AlertDismissedScreen extends StatelessWidget {
  const AlertDismissedScreen({
    required this.placeName,
    required this.onContinue,
    super.key,
  });

  final String placeName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.check_circle_outlined,
                size: 56,
                color: semantic.statusActive,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('알림을 껐습니다', style: AppTypography.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(placeName, style: AppTypography.caption),
              const Spacer(),
              // 광고 자리 — google_mobile_ads 통합 시 이 위치에 배너/전면 삽입
              FilledButton(onPressed: onContinue, child: const Text('확인')),
            ],
          ),
        ),
      ),
    );
  }
}
