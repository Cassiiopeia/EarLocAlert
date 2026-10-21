import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import 'pro_offer_sheet.dart';

/// 등급 표시 칩 (#294): 무료 FREE(누르면 프로 안내), 프로 PRO. 결제가 없는 플랫폼은 숨김
class PlanBadgeChip extends ConsumerWidget {
  const PlanBadgeChip({super.key, this.entryPoint = 'home_chip'});

  /// 프로 안내 로그용 진입점 이름
  final String entryPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(featureAccessControllerProvider);
    if (!access.isPaywallEnabled) return const SizedBox.shrink();
    final chip = PlanLabel(isPro: access.isPro);
    if (access.isPro) return chip;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showProOfferSheet(context, entryPoint: entryPoint),
        // 칩은 작아서 주변까지 탭을 받는다
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs / 2),
          child: chip,
        ),
      ),
    );
  }
}

/// FREE / PRO 글자 배지 (회색 / 민트)
class PlanLabel extends StatelessWidget {
  const PlanLabel({super.key, required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPro ? colors.accent : colors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: isPro ? null : Border.all(color: colors.separator),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs / 4,
        ),
        child: Text(
          isPro ? context.l10n.proChipPro : context.l10n.proChipFree,
          style: context.appTextStyles.caption.copyWith(
            color: isPro ? colors.onAccent : colors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
