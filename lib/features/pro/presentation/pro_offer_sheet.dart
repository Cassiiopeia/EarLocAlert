import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/entitlement/pro_entitlement.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/pro_purchase_providers.dart';
import '../domain/pro_purchase_service.dart';
import 'plan_badge_chip.dart';
import 'pro_price_provider.dart';

/// 프로 안내 시트 열기 (#294). 결제가 없는 플랫폼에서는 아무것도 하지 않음
/// entryPoint: 로그용 진입점 (place_add · sound_picker · backup · settings_card · home_chip)
Future<void> showProOfferSheet(
  BuildContext context, {
  required String entryPoint,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final access = container.read(featureAccessControllerProvider);
  // 결제 없는 플랫폼·이미 프로·이미 열림(빠른 두 번 탭) > 열지 않음
  if (!access.isPaywallEnabled || access.isPro || _isOfferSheetOpen) return;
  Diagnostics.log('pro', 'offer shown entry=$entryPoint');
  _isOfferSheetOpen = true;
  try {
    await showAppBottomSheet<void>(
      context,
      builder: (context) => const _ProOfferSheet(),
    );
  } finally {
    _isOfferSheetOpen = false;
  }
}

/// 프로 안내 시트가 떠 있는가 — 한 번에 한 장만
bool _isOfferSheetOpen = false;

/// 평생 이용권 시트: 배지 > 제목 > 무료·프로 비교표 > 구매 버튼 > 복원
class _ProOfferSheet extends ConsumerStatefulWidget {
  const _ProOfferSheet();

  @override
  ConsumerState<_ProOfferSheet> createState() => _ProOfferSheetState();
}

class _ProOfferSheetState extends ConsumerState<_ProOfferSheet> {
  StreamSubscription<ProPurchaseEvent>? _events;

  /// 결제 창·복원 조회가 진행 중인가 (버튼 중복 탭 방지)
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _events = ref
        .read(proPurchaseServiceProvider)
        .events
        .listen(_onPurchaseEvent);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  /// 결제 결과 > 안내 문구. 프로가 되면 시트는 아래 listen 이 닫음
  void _onPurchaseEvent(ProPurchaseEvent event) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (event) {
      case ProPurchased() || ProRestored():
        context.showToast(l10n.proPurchaseDone);
      case ProPurchasePending():
        context.showToast(l10n.proPurchasePending);
      case ProPurchaseFailed():
        context.showToast(l10n.proPurchaseFailed);
      case ProPurchaseCancelled():
        break;
    }
    setState(() => _isBusy = false);
  }

  Future<void> _buy() async {
    setState(() => _isBusy = true);
    final launched = await ref.read(proPurchaseServiceProvider).buy();
    if (!mounted) return;
    if (!launched) {
      setState(() => _isBusy = false);
      context.showToast(context.l10n.proProductUnavailable);
    }
  }

  /// 복원: Play 보유 조회 > 있으면 프로, 없으면 안내 (조회 실패도 안내)
  Future<void> _restore() async {
    setState(() => _isBusy = true);
    final isOwned = await ref
        .read(proPurchaseServiceProvider)
        .hasOwnedPurchase();
    Diagnostics.log('pro', 'restore result owned=$isOwned');
    if (!mounted) return;
    setState(() => _isBusy = false);
    final l10n = context.l10n;
    switch (isOwned) {
      case true:
        context.showToast(l10n.proRestoreDone);
        await ref
            .read(featureAccessControllerProvider.notifier)
            .setSource(ProEntitlementSource.purchase, reason: 'restored');
      case false:
        context.showToast(l10n.proRestoreNone);
      case null:
        context.showToast(l10n.proProductUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 프로가 되면 시트를 닫는다 (구매·복원 어느 경로든)
    ref.listen(featureAccessControllerProvider, (previous, next) {
      if (next.isPro && !(previous?.isPro ?? false)) {
        Navigator.of(context).maybePop();
      }
    });
    final price = ref.watch(proPriceProvider);
    final l10n = context.l10n;
    final colors = context.appColors;

    return BottomSheetWithHeaderLayout(
      title: l10n.proSheetTitle,
      headerTrailing: const PlanLabel(isPro: true),
      description: l10n.proSheetSubtitle,
      body: const _PlanComparisonTable(),
      primaryAction: _BuyButton(price: price, isBusy: _isBusy, onPressed: _buy),
      secondaryAction: TextButton(
        onPressed: _isBusy ? null : _restore,
        style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
        child: Text(l10n.proSheetRestore),
      ),
    );
  }
}

/// 구매 버튼: 가격 확인 중 > `평생 이용권 {가격}` / 상품 못 읽음 > 비활성 + 사유
class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.price,
    required this.isBusy,
    required this.onPressed,
  });

  final AsyncValue<String?> price;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final loadedPrice = price.valueOrNull;
    final isPriceUnavailable = !price.isLoading && loadedPrice == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: (loadedPrice == null || isBusy) ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
            minimumSize: const Size.fromHeight(AppControlSize.primary),
            shape: const StadiumBorder(),
            textStyle: context.appTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: isBusy
              ? const InlineLoadingIndicator()
              : Text(
                  loadedPrice == null
                      ? l10n.proPriceLoading
                      : l10n.proSheetBuy(loadedPrice),
                ),
        ),
        if (isPriceUnavailable)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              context.keepAllText(l10n.proProductUnavailable),
              style: context.appTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// 무료·프로 비교표 (시안 B): 행 7개, 프로 열은 민트 강조
class _PlanComparisonTable extends StatelessWidget {
  const _PlanComparisonTable();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    // 행: (항목, 무료 값, 프로 값). 값 null = 체크 표시, '' = 불가 표시
    final rows = <(String, String?, String?)>[
      (l10n.proRowPlaces, l10n.proValueOnePlace, l10n.proValueUnlimited),
      (l10n.proRowDirections, null, null),
      (l10n.proRowSchedules, null, null),
      (l10n.proRowVibration, null, null),
      (l10n.proRowSound, l10n.proValueDefaultSound, l10n.proValueAllSounds),
      (l10n.proRowBackup, '', null),
      (l10n.proRowAds, l10n.proValueAdsOn, l10n.proValueAdsOff),
    ];

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        children: [
          _ComparisonRow(
            label: '',
            free: Text(
              l10n.proSheetColumnFree,
              style: context.appTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            pro: Text(
              l10n.proSheetColumnPro,
              style: context.appTextStyles.caption.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          for (final (label, free, pro) in rows) ...[
            Divider(height: 1, thickness: 1, color: colors.separator),
            _ComparisonRow(
              label: label,
              free: _ComparisonValue(value: free, isPro: false),
              pro: _ComparisonValue(value: pro, isPro: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.free,
    required this.pro,
  });

  final String label;
  final Widget free;
  final Widget pro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + AppSpacing.xs / 4,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              context.keepAllText(label),
              style: context.appTextStyles.body,
            ),
          ),
          Expanded(flex: 3, child: free),
          Expanded(flex: 4, child: pro),
        ],
      ),
    );
  }
}

/// 표 칸 값: null 체크 아이콘 / '' 불가(—) / 글자
class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.value, required this.isPro});

  final String? value;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isPro ? colors.accent : colors.textSecondary;
    final text = value;
    if (text == null) {
      return Icon(Icons.check_rounded, size: AppIconSize.inline, color: color);
    }
    return Text(
      text.isEmpty ? '—' : context.keepAllText(text),
      style: context.appTextStyles.caption.copyWith(
        color: color,
        fontWeight: isPro ? FontWeight.w700 : FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }
}
