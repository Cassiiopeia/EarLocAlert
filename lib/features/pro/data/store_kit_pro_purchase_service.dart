import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/platform/channel_names.dart';
import '../domain/pro_purchase_record.dart';
import '../domain/pro_purchase_service.dart';

/// App Store 비소모성 상품 `pro_unlock` 결제 (#298)
/// 흐름: 구매 스트림 구독(생성 즉시) > 상품 조회 > 결제 창 > 거래 완료 처리(finish)
/// 보유 조회: StoreKit 2 currentEntitlements 복원 — 로그인 창 없음, 환불된 구매는 빠짐
class StoreKitProPurchaseService implements ProPurchaseService {
  StoreKitProPurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) =>
          Diagnostics.log('pro', 'purchase stream error error=$error'),
    );
  }

  // App Store Connect 비소모성 상품 ID (Play 상품과 같은 ID)
  static const String productId = 'pro_unlock';

  // 복원 완료 응답 뒤 복원 거래가 스트림으로 늦게 도착할 여유 (응답과 거래가 다른 채널)
  static const Duration _restoreSettleDuration = Duration(milliseconds: 600);

  final InAppPurchase _store;
  final _events = StreamController<ProPurchaseEvent>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  ProductDetails? _product;

  /// 보유 조회 진행 중이면 같은 결과를 공유 (시작·복귀·복원이 겹쳐도 1회)
  Future<bool?>? _ownedQuery;

  /// 보유 조회 중 도착한 복원 거래 — 조회 결과로만 쓰고 이벤트로 보내지 않음
  List<PurchaseDetails>? _restoredDuringQuery;

  @override
  ProPurchaseStore get store => ProPurchaseStore.appStore;

  static const _offerCodeChannel = MethodChannel(ChannelNames.offerCode);

  /// App Store 오퍼 코드 시트 (Swift `OfferCodeRedeemSheet`). 시트가 닫히면 돌아온다 (#305)
  @override
  Future<bool> openPromoCodeRedemption() async {
    try {
      return await _offerCodeChannel.invokeMethod<bool>('present') ?? false;
    } on Object catch (error) {
      Diagnostics.log('pro', 'offer code sheet threw error=$error');
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
        // 상품 미등록·유료 앱 계약 미서명이면 여기로 온다
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

  /// 결제 창 열기. 이미 산 계정은 App Store 가 결제 없이 구매 거래를 다시 돌려줌
  @override
  Future<bool> buy() async {
    final product = await _loadProduct();
    if (product == null) return false;
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      Diagnostics.log('pro', 'purchase started launched=$started');
      return started;
    } on Object catch (error) {
      Diagnostics.log('pro', 'purchase start threw error=$error');
      return false;
    }
  }

  @override
  Future<bool?> hasOwnedPurchase() => _ownedQuery ??= _queryOwnedPurchase()
      .whenComplete(() => _ownedQuery = null);

  /// 보유 조회: 복원 요청 > 도착한 복원 거래 수집 > 대상 상품이 있으면 보유
  /// 복원 요청이 실패해도 대상 상품이 도착했으면 보유로 본다. 안 왔고 실패면 null
  Future<bool?> _queryOwnedPurchase() async {
    try {
      if (!await _store.isAvailable()) {
        Diagnostics.log('pro', 'owned query skipped reason=store_unavailable');
        return null;
      }
    } on Object catch (error) {
      Diagnostics.log('pro', 'owned query threw error=$error');
      return null;
    }
    final restored = <PurchaseDetails>[];
    _restoredDuringQuery = restored;
    Object? restoreError;
    try {
      await _store.restorePurchases();
      await Future<void>.delayed(_restoreSettleDuration);
    } on Object catch (error) {
      restoreError = error;
    } finally {
      _restoredDuringQuery = null;
    }
    final owned = restored
        .where((purchase) => purchase.productID == productId)
        .toList();
    if (owned.isNotEmpty) _ownedRecord = _recordOf(owned.first);
    if (owned.isEmpty && restoreError != null) {
      Diagnostics.log('pro', 'owned query failed error=$restoreError');
      return null;
    }
    Diagnostics.log('pro', 'owned query done owned=${owned.isNotEmpty}');
    return owned.isNotEmpty;
  }

  /// 거래 상태별 처리: 거래 완료 처리 > 이벤트 전달 (보유 조회 중 복원은 수집만)
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
      // 완료 처리하지 않은 거래는 App Store 가 실행마다 다시 보냄 (상태 공통)
      await _finishIfNeeded(purchase);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // 자녀 계정 구매 승인 요청(Ask to Buy) 등
          _events.add(const ProPurchasePending());
        case PurchaseStatus.purchased:
          _events.add(ProPurchased(_recordOf(purchase)));
        case PurchaseStatus.restored:
          final collecting = _restoredDuringQuery;
          if (collecting != null) {
            collecting.add(purchase);
            continue;
          }
          _events.add(ProRestored(_recordOf(purchase)));
        case PurchaseStatus.canceled:
          _events.add(const ProPurchaseCancelled());
        case PurchaseStatus.error:
          final error = purchase.error;
          Diagnostics.log(
            'pro',
            'purchase failed code=${error?.code} message=${error?.message}',
          );
          _events.add(ProPurchaseFailed(error?.message ?? 'unknown'));
      }
    }
  }

  /// 거래 정보 > 기록 (거래 ID, 구매 시각)
  static ProPurchaseRecord _recordOf(PurchaseDetails purchase) {
    final transactionId = purchase.purchaseID;
    return ProPurchaseRecord(
      orderId: transactionId == null || transactionId.isEmpty
          ? null
          : transactionId,
      purchasedAt: _parsePurchaseDate(purchase.transactionDate),
    );
  }

  /// 구매 시각 문자열 > UTC
  /// StoreKit 2: `yyyy-MM-dd HH:mm:ss`(기기 시간대), StoreKit 1: epoch 밀리초
  static DateTime? _parsePurchaseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final milliseconds = int.tryParse(raw);
    if (milliseconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// 거래 완료 처리(finish). 실패하면 다음 실행에서 같은 거래가 다시 와 재시도
  Future<void> _finishIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _store.completePurchase(purchase);
      Diagnostics.log('pro', 'purchase finished');
    } on Object catch (error) {
      Diagnostics.log('pro', 'purchase finish threw error=$error');
    }
  }

  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_events.close());
  }
}
