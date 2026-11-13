import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/pro_purchase_providers.dart';
import '../domain/pro_offer_entry.dart';
import '../domain/pro_purchase_service.dart';
import 'plan_badge_chip.dart';
import 'pro_comparison_table.dart';
import 'pro_price_provider.dart';
import 'pro_restore_action.dart';

/// 프로 안내 시트 열기 (#294, #366): 들어온 자리에 맞춘 제목·강조 > 닫힌 뒤 프로가 됐으면 true
/// 결제 없는 플랫폼·이미 프로·이미 열림 > 열지 않고 false
Future<bool> showProOfferSheet(
  BuildContext context, {
  required ProOfferEntry entry,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final access = container.read(featureAccessControllerProvider);
  if (!access.isPaywallEnabled || access.isPro || _isOfferSheetOpen) {
    return false;
  }
  Diagnostics.log('pro', 'offer shown entry=${entry.logName}');
  _isOfferSheetOpen = true;
  try {
    await showAppBottomSheet<void>(
      context,
      builder: (context) => _ProOfferSheet(highlight: entry.highlight),
    );
  } finally {
    _isOfferSheetOpen = false;
  }
  final isProNow = container.read(featureAccessControllerProvider).isPro;
  Diagnostics.log(
    'pro',
    'offer closed entry=${entry.logName} unlocked=$isProNow',
  );
  return isProNow;
}

/// 프로 안내 시트가 떠 있는가 — 한 번에 한 장만
bool _isOfferSheetOpen = false;

/// 평생 이용권 시트: 들어온 자리 제목 > 결제 방식 한 줄 > 비교표 > 구매 버튼 > 복원·코드
class _ProOfferSheet extends ConsumerStatefulWidget {
  const _ProOfferSheet({required this.highlight});

  final ProOfferHighlight highlight;

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

  /// 스토어 프로모션 코드 입력 화면 (#294, #305)
  /// Play: 앱 밖 화면 > 돌아오면 복귀 시 보유 조회 · App Store: 앱 위 시트 > 닫히면 바로 보유 조회
  Future<void> _openPromoCodeRedeem() async {
    final service = ref.read(proPurchaseServiceProvider);
    Diagnostics.log(
      'pro',
      'promo code redeem opened store=${service.store.name}',
    );
    final opened = await service.openPromoCodeRedemption();
    if (!mounted) return;
    if (!opened) {
      Diagnostics.log('pro', 'promo code redeem open failed');
      context.showToast(context.l10n.settingsOpenLinkFailed);
      return;
    }
    if (service.store == ProPurchaseStore.appStore) {
      setState(() => _isBusy = true);
      await syncProAfterPromoCode(context, ref);
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// 복원: 보유 조회 > 있으면 프로, 없으면 안내 (조회 실패도 안내)
  Future<void> _restore() async {
    setState(() => _isBusy = true);
    await restoreProPurchase(context, ref);
    if (mounted) setState(() => _isBusy = false);
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
    // 코드 입력은 무료일 때만 (#305) — Play·App Store 둘 다. 결제 없는 플랫폼은 숨김
    final store = ref.watch(proPurchaseServiceProvider).store;
    final canRedeemPromoCode =
        store != ProPurchaseStore.none &&
        !ref.watch(featureAccessControllerProvider).isPro;
    final l10n = context.l10n;
    final colors = context.appColors;

    return BottomSheetWithHeaderLayout(
      title: _headlineOf(l10n, widget.highlight),
      headerTrailing: const PlanLabel(isPro: true),
      // 구매 계정은 스토어마다 다름 (Play > Google, App Store > Apple)
      description: store == ProPurchaseStore.appStore
          ? l10n.proSheetSubtitleApple
          : l10n.proSheetSubtitleGoogle,
      body: ProComparisonTable(highlight: widget.highlight),
      primaryAction: _BuyButton(price: price, isBusy: _isBusy, onPressed: _buy),
      // 구매 버튼 아래: 복원 > 프로모션 코드 (프로면 시트 자체가 안 열려 둘 다 안 보임)
      secondaryAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _isBusy ? null : _restore,
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            child: Text(l10n.proSheetRestore),
          ),
          if (canRedeemPromoCode)
            TextButton(
              onPressed: _isBusy ? null : _openPromoCodeRedeem,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
              ),
              // 같은 기능의 스토어 용어: Play 프로모션 코드 / App Store 오퍼 코드
              child: Text(
                store == ProPurchaseStore.appStore
                    ? l10n.proSheetRedeemAppStore
                    : l10n.proSheetRedeem,
              ),
            ),
        ],
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
                  loadedPrice != null
                      ? l10n.proSheetBuy(loadedPrice)
                      // 상품을 못 읽음 > 가격 없이 이름만 (아래 사유 문구가 이유를 말함)
                      : isPriceUnavailable
                      ? l10n.proSheetTitle
                      : l10n.proPriceLoading,
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

/// 강조 혜택 > 시트 제목 (얻는 것을 먼저)
String _headlineOf(AppLocalizations l10n, ProOfferHighlight highlight) =>
    switch (highlight) {
      ProOfferHighlight.general => l10n.proHeadlineGeneral,
      ProOfferHighlight.places => l10n.proHeadlinePlaces,
      ProOfferHighlight.sounds => l10n.proHeadlineSounds,
      ProOfferHighlight.vibrationPatterns => l10n.proHeadlineVibrationPatterns,
      ProOfferHighlight.history => l10n.proHeadlineHistory,
      ProOfferHighlight.routines => l10n.proHeadlineRoutines,
      ProOfferHighlight.backup => l10n.proHeadlineBackup,
    };
