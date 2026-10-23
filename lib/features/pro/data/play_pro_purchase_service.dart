import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/pro_purchase_record.dart';
import '../domain/pro_purchase_service.dart';

/// Google Play 일회성 상품 `pro_unlock` 결제 (#294)
/// 흐름: 구매 스트림 구독(생성 즉시) > 상품 조회 > 결제 창 > 구매 확인(acknowledge)
class PlayProPurchaseService implements ProPurchaseService {
  PlayProPurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) =>
          Diagnostics.log('pro', 'purchase stream error error=$error'),
    );
  }

  // Play Console 일회성 상품 ID
  static const String productId = 'pro_unlock';

  final InAppPurchase _store;
  final _events = StreamController<ProPurchaseEvent>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  ProductDetails? _product;

  /// 보유 조회 진행 중이면 같은 결과를 공유 (시작·복귀·복원이 겹쳐도 1회)
  Future<bool?>? _ownedQuery;

  @override
  ProPurchaseStore get store => ProPurchaseStore.googlePlay;

  // Play 스토어 코드 사용 화면 — 프로모션 코드를 넣으면 구매로 기록됨
  static final Uri _redeemUri = Uri.parse('https://play.google.com/redeem');

  /// Play 코드 사용 화면 열기. 앱으로 돌아오면 복귀 시 보유 조회가 프로로 반영 (#294)
  @override
  Future<bool> openPromoCodeRedemption() async {
    try {
      return await launchUrl(_redeemUri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      Diagnostics.log('pro', 'promo code redeem open threw error=$error');
      return false;
    }
  }

  @override
  ProPurchaseRecord? get ownedRecord => _ownedRecord;
  ProPurchaseRecord? _ownedRecord;

  @override
  Stream<ProPurchaseEvent> get events => _events.stream;

  @override
  Future<String?> loadPrice() async => (await _loadProduct())?.price;

  /// 상품 정보 1회 조회 후 보관. 실패하면 다음 호출에서 다시 시도
  Future<ProductDetails?> _loadProduct() async {
    final cached = _product;
    if (cached != null) return cached;
    try {
      if (!await _store.isAvailable()) {
        Diagnostics.log(
          'pro',
          'product query skipped reason=store_unavailable',
        );
        return null;
      }
      final response = await _store.queryProductDetails({productId});
      final error = response.error;
      if (error != null) {
        Diagnostics.log(
          'pro',
          'product query failed code=${error.code} message=${error.message}',
        );
        return null;
      }
      if (response.productDetails.isEmpty) {
        Diagnostics.log(
          'pro',
          'product query empty not_found=${response.notFoundIDs.join(",")}',
        );
        return null;
      }
      final product = response.productDetails.first;
      Diagnostics.log('pro', 'product loaded price=${product.price}');
      return _product = product;
    } on Object catch (error) {
      Diagnostics.log('pro', 'product query threw error=$error');
      return null;
    }
  }

  /// 결제 창 열기. 못 열면 이미 보유했는지 확인 > 보유면 복원으로 처리
  @override
  Future<bool> buy() async {
    final product = await _loadProduct();
    if (product == null) return false;
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      Diagnostics.log('pro', 'purchase started launched=$started');
      if (started) return true;
    } on Object catch (error) {
      Diagnostics.log('pro', 'purchase start threw error=$error');
    }
    // 이미 산 계정은 결제 창 대신 ITEM_ALREADY_OWNED 로 거절된다
    if (await hasOwnedPurchase() ?? false) {
      _events.add(ProRestored(_ownedRecord));
      return true;
    }
    return false;
  }

  @override
  Future<bool?> hasOwnedPurchase() => _ownedQuery ??= _queryOwnedPurchase()
      .whenComplete(() => _ownedQuery = null);

  /// 과거 구매 조회: 대상 상품이 purchased 로 있으면 보유(미확인이면 확인까지)
  /// 구독 쪽 오류가 섞여도 대상 상품이 보이면 보유로 본다. 안 보이고 오류면 null
  Future<bool?> _queryOwnedPurchase() async {
    try {
      if (!await _store.isAvailable()) {
        Diagnostics.log('pro', 'owned query skipped reason=store_unavailable');
        return null;
      }
      final addition = _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      final owned = response.pastPurchases
          .where(
            (purchase) =>
                purchase.productID == productId &&
                purchase.status == PurchaseStatus.purchased,
          )
          .toList();
      // 확인되지 않은 구매는 여기서 마저 확인 — 3일 안에 안 하면 Play 가 자동 환불
      for (final purchase in owned) {
        await _acknowledgeIfNeeded(purchase);
      }
      if (owned.isNotEmpty) _ownedRecord = _recordOf(owned.first);
      final error = response.error;
      if (owned.isEmpty && error != null) {
        Diagnostics.log(
          'pro',
          'owned query failed code=${error.code} message=${error.message}',
        );
        return null;
      }
      Diagnostics.log('pro', 'owned query done owned=${owned.isNotEmpty}');
      return owned.isNotEmpty;
    } on Object catch (error) {
      Diagnostics.log('pro', 'owned query threw error=$error');
      return null;
    }
  }

  /// 구매 상태별 처리: 구매 확인 > 이벤트 전달
  /// 상품 ID 가 빈 결과 = 결제 창이 끝난 결과(취소·오류) — 진행 중 흐름의 결과로 처리
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final isTargetProduct =
          purchase.productID == productId || purchase.productID.isEmpty;
      if (!isTargetProduct) continue;
      Diagnostics.log(
        'pro',
        'purchase update status=${purchase.status.name} '
            'product=${purchase.productID.isEmpty ? "none" : purchase.productID}',
      );
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _events.add(const ProPurchasePending());
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 상품 ID 없는 "ok" 결과는 구매 정보가 없다 — 보유 조회로 확정
          if (purchase.productID.isEmpty) {
            await _emitRestoredIfOwned();
            continue;
          }
          await _acknowledgeIfNeeded(purchase);
          final record = _recordOf(purchase);
          _events.add(
            purchase.status == PurchaseStatus.purchased
                ? ProPurchased(record)
                : ProRestored(record),
          );
        case PurchaseStatus.canceled:
          _events.add(const ProPurchaseCancelled());
        case PurchaseStatus.error:
          final error = purchase.error;
          Diagnostics.log(
            'pro',
            'purchase failed code=${error?.code} message=${error?.message}',
          );
          // 이미 보유 > 복원으로 처리
          if (error?.message.contains('itemAlreadyOwned') ?? false) {
            await _emitRestoredIfOwned();
            continue;
          }
          _events.add(ProPurchaseFailed(error?.message ?? 'unknown'));
      }
    }
  }

  Future<void> _emitRestoredIfOwned() async {
    final isOwned = await hasOwnedPurchase();
    _events.add(
      isOwned ?? false
          ? ProRestored(_ownedRecord)
          : const ProPurchaseFailed('not_owned'),
    );
  }

  /// 구매 정보 > 기록 (주문 번호, 구매 시각 epoch 밀리초 문자열)
  static ProPurchaseRecord _recordOf(PurchaseDetails purchase) {
    final purchasedAtMilliseconds = int.tryParse(
      purchase.transactionDate ?? '',
    );
    final orderId = purchase.purchaseID;
    return ProPurchaseRecord(
      orderId: orderId == null || orderId.isEmpty ? null : orderId,
      purchasedAt: purchasedAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              purchasedAtMilliseconds,
              isUtc: true,
            ),
    );
  }

  /// 구매 확인(acknowledge). Android 는 실패해도 예외 없이 응답 코드만 줌 > 코드로 판정
  /// 실패 시 다음 보유 조회(시작·앱 복귀)에서 다시 시도
  Future<void> _acknowledgeIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      // InAppPurchase.completePurchase 는 결과를 버린다 > Android 플랫폼을 직접 호출
      final platform = InAppPurchasePlatform.instance;
      if (platform is! InAppPurchaseAndroidPlatform) {
        await _store.completePurchase(purchase);
        return;
      }
      final code = (await platform.completePurchase(purchase)).responseCode;
      if (code == BillingResponse.ok) {
        Diagnostics.log('pro', 'purchase acknowledged');
      } else {
        Diagnostics.log(
          'pro',
          'purchase acknowledge failed code=${code.name} retry=next_owned_query',
        );
      }
    } on Object catch (error) {
      Diagnostics.log('pro', 'purchase acknowledge threw error=$error');
    }
  }

  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_events.close());
  }
}

/// 결제를 쓰지 않는 플랫폼(Android·iOS 외)용 — 아무것도 하지 않음
class NoopProPurchaseService implements ProPurchaseService {
  const NoopProPurchaseService();

  @override
  ProPurchaseStore get store => ProPurchaseStore.none;

  @override
  Stream<ProPurchaseEvent> get events => const Stream.empty();

  @override
  Future<String?> loadPrice() async => null;

  @override
  Future<bool> buy() async => false;

  @override
  Future<bool?> hasOwnedPurchase() async => null;

  @override
  ProPurchaseRecord? get ownedRecord => null;

  @override
  Future<bool> openPromoCodeRedemption() async => false;
}
