import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/entitlement/feature_access_controller.dart';
import '../core/entitlement/pro_entitlement.dart';
import '../features/places/data/place_repository_provider.dart';
import '../features/places/domain/place_repository.dart';
import '../features/pro/data/pro_purchase_providers.dart';
import '../features/pro/domain/pro_purchase_record.dart';
import '../features/pro/domain/pro_purchase_service.dart';
import '../features/pro/presentation/pro_purchase_record_controller.dart';

part 'pro_access_coordinator.g.dart';

/// 앱 시작 시 프로 상태 맞추기: 구매 구독 > 기존 사용자 판정 > Play 보유 조회 (#294)
/// places 와 pro 의 협력은 app 계층이 조율 (docs/02-ARCHITECTURE.md 규칙 1)
class ProAccessCoordinator {
  ProAccessCoordinator({
    required ProPurchaseService purchases,
    required PlaceRepository places,
    required ProEntitlementStore store,
    required ProEntitlementSource Function() currentSource,
    required Future<void> Function(
      ProEntitlementSource, {
      required String reason,
    })
    setSource,
    required bool isPaywallEnabled,
    required Future<void> Function(ProPurchaseRecord?) saveRecord,
  }) : _saveRecord = saveRecord,
       _purchases = purchases,
       _places = places,
       _store = store,
       _currentSource = currentSource,
       _setSource = setSource,
       _isPaywallEnabled = isPaywallEnabled;

  final ProPurchaseService _purchases;
  final PlaceRepository _places;
  final ProEntitlementStore _store;
  final ProEntitlementSource Function() _currentSource;
  final Future<void> Function(ProEntitlementSource, {required String reason})
  _setSource;
  final bool _isPaywallEnabled;

  /// 구매 기록 저장 (이용권 정보 시트 표시용)
  final Future<void> Function(ProPurchaseRecord?) _saveRecord;

  StreamSubscription<ProPurchaseEvent>? _events;

  /// 보유 조회 중에 구매가 끝났는지 가르는 번호 — 조회 전 결과로 방금 산 사람을 무료로 되돌리지 않게
  int _purchaseGeneration = 0;

  /// 1회만 실행. 실패는 삼키고 기록 (시작 흐름을 막지 않음)
  Future<void> start() async {
    if (_events != null) return;
    // 구매 결과 구독 먼저 — 지난 실행에서 끝난 결제도 이 스트림으로 옴
    _events = _purchases.events.listen(_onPurchaseEvent);
    await _grantLegacyUserOnce();
    if (_isPaywallEnabled) await _syncOwnedPurchase();
  }

  void _onPurchaseEvent(ProPurchaseEvent event) {
    if (event is ProPurchased || event is ProRestored) _purchaseGeneration++;
    switch (event) {
      case ProPurchased(:final record):
        unawaited(_saveRecord(record));
        unawaited(_grantPurchase('purchased'));
      case ProRestored(:final record):
        unawaited(_saveRecord(record));
        unawaited(_grantPurchase('restored'));
      case ProPurchasePending() ||
          ProPurchaseCancelled() ||
          ProPurchaseFailed():
        break;
    }
  }

  /// 구매·복원 반영. 기존 사용자 혜택은 그대로 둠
  Future<void> _grantPurchase(String reason) async {
    if (_currentSource() == ProEntitlementSource.legacyUser) return;
    await _setSource(ProEntitlementSource.purchase, reason: reason);
  }

  /// 기존 사용자 판정 (모든 플랫폼, 기기당 1회): 판정 시점에 장소가 있으면 혜택
  /// iOS 는 기록만 — 나중에 결제를 붙일 때 판정 시점이 밀리지 않게
  Future<void> _grantLegacyUserOnce() async {
    // 디버그 강제 등급이면 판정·저장하지 않음 (에뮬레이터 확인 상태 보존)
    if (debugProSourceOverride() != null) {
      Diagnostics.log('pro', 'legacy check skipped reason=debug_override');
      return;
    }
    try {
      if (await _store.isLegacyCheckDone()) return;
      final placeCount = (await _places.findAll()).length;
      final isGranted =
          placeCount > 0 && _currentSource() == ProEntitlementSource.none;
      if (isGranted) {
        await _setSource(
          ProEntitlementSource.legacyUser,
          reason: 'legacy_user',
        );
      }
      await _store.markLegacyCheckDone();
      Diagnostics.log(
        'pro',
        'legacy check done places=$placeCount granted=$isGranted',
      );
    } on Object catch (error) {
      // 판정 완료 표시 전이라 다음 실행에서 다시 판정
      Diagnostics.log('pro', 'legacy check failed error=$error');
    }
  }

  /// Play 보유 조회로 구매 상태 맞추기: 보유 > 프로, 구매였는데 없음 > 무료(환불), 조회 실패 > 유지
  /// 기존 사용자 혜택은 Play 와 무관해 건드리지 않음
  /// 앱이 다시 앞으로 왔을 때 — 확인 못 한 구매를 마저 확인하고 상태를 맞춤
  Future<void> onResumed() async {
    if (_isPaywallEnabled && _events != null) await _syncOwnedPurchase();
  }

  Future<void> _syncOwnedPurchase() async {
    if (debugProSourceOverride() != null) {
      Diagnostics.log('pro', 'owned sync skipped reason=debug_override');
      return;
    }
    final generationAtQuery = _purchaseGeneration;
    final isOwned = await _purchases.hasOwnedPurchase();
    final current = _currentSource();
    if (isOwned == null) {
      Diagnostics.log(
        'pro',
        'owned sync kept source=${current.storageValue} reason=query_failed',
      );
      return;
    }
    if (isOwned) {
      await _saveRecord(_purchases.ownedRecord);
      // 기존 사용자 혜택은 덮어쓰지 않음 — 나중에 환불돼도 혜택이 남게
      if (current == ProEntitlementSource.none) {
        await _setSource(
          ProEntitlementSource.purchase,
          reason: 'owned_on_sync',
        );
      }
    } else if (current == ProEntitlementSource.purchase &&
        generationAtQuery == _purchaseGeneration) {
      await _setSource(ProEntitlementSource.none, reason: 'refund_detected');
    }
  }

  void dispose() => unawaited(_events?.cancel());
}

@Riverpod(keepAlive: true)
ProAccessCoordinator proAccessCoordinator(Ref ref) {
  final access = ref.read(featureAccessControllerProvider.notifier);
  final coordinator = ProAccessCoordinator(
    purchases: ref.watch(proPurchaseServiceProvider),
    places: ref.watch(placeRepositoryProvider),
    store: ref.watch(proEntitlementStoreProvider),
    currentSource: () => ref.read(featureAccessControllerProvider).source,
    setSource: access.setSource,
    isPaywallEnabled: ref
        .read(featureAccessControllerProvider)
        .isPaywallEnabled,
    saveRecord: ref.read(proPurchaseRecordControllerProvider.notifier).save,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
}
