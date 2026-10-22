import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/grouped_list_row.dart';
import '../../../core/ui/components/grouped_list_section.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import 'plan_badge_chip.dart';
import 'pro_info_sheet.dart';
import 'pro_offer_sheet.dart';
import 'pro_price_provider.dart';

/// 설정 맨 위 등급 영역 (#294): 무료 > 큰 유도 카드, 프로 > 한 줄. 결제가 없는 플랫폼은 숨김
class ProSettingsCard extends ConsumerWidget {
  const ProSettingsCard({super.key, required this.placeCount});

  /// 지금 등록된 장소 수 — 무료 카드의 사용량 표시
  final int placeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(featureAccessControllerProvider);
    if (!access.isPaywallEnabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: access.isPro
          ? const _ProOwnedRow()
          : _FreeUpgradeCard(
              placeCount: placeCount,
              placeLimit: access.placeLimit,
            ),
    );
  }
}

/// 무료 유도 카드: FREE·사용량 > 제목 > 혜택 > 구매 버튼
class _FreeUpgradeCard extends ConsumerWidget {
  const _FreeUpgradeCard({required this.placeCount, required this.placeLimit});

  final int placeCount;
  final int placeLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final price = ref.watch(proPriceProvider).valueOrNull;
    void openOffer() => showProOfferSheet(context, entryPoint: 'settings_card');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openOffer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            // 민트를 살짝 섞은 면 > 다른 묶음 카드와 구분
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(colors.surface, colors.accent, 0.18)!,
                colors.surface,
              ],
            ),
            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PlanLabel(isPro: false),
                  const Spacer(),
                  Text(
                    l10n.proCardUsage(placeCount, placeLimit),
                    style: context.appTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.keepAllText(l10n.proCardTitle),
                style: context.appTextStyles.headline,
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                context.keepAllText(l10n.proCardSubtitle),
                style: context.appTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: openOffer,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  shape: const StadiumBorder(),
                  textStyle: context.appTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  price == null ? l10n.proRowLifetime : l10n.proSheetBuy(price),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 프로 한 줄: 평생 이용권 · PRO (밖에는 이것만). 누르면 이용권 정보 시트
class _ProOwnedRow extends StatelessWidget {
  const _ProOwnedRow();

  @override
  Widget build(BuildContext context) {
    return GroupedListSection(
      children: [
        GroupedListRow.withTrailing(
          icon: Icons.workspace_premium_outlined,
          iconColor: context.appColors.accent,
          title: context.l10n.proRowLifetime,
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [PlanLabel(isPro: true), Icon(Icons.chevron_right)],
          ),
          onTap: () => showProInfoSheet(context),
        ),
      ],
    );
  }
}
