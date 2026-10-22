import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/entitlement/feature_access_controller.dart';
import '../core/entitlement/pro_entitlement.dart';
import '../features/pro/data/pro_purchase_providers.dart';
import '../features/pro/domain/pro_purchase_record.dart';
import '../features/pro/domain/pro_purchase_service.dart';
import '../features/pro/presentation/pro_purchase_record_controller.dart';

part 'pro_access_coordinator.g.dart';

/// 앱 시작·복귀 시 프로 상태 맞추기: 구매 구독 > Play 보유 조회 (#294)
/// 기존 사용자 자동 혜택은 없음 — 무료로 줄 사람은 Play 프로모션 코드 (결정 072)
class ProAccessCoordinator {
  ProAccessCoordinator({
    required ProPurchaseService purchases,
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
       _currentSource = currentSource,
       _setSource = setSource,
       _isPaywallEnabled = isPaywallEnabled;

  final ProPurchaseService _purchases;
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

  /// 구매·복원(프로모션 코드 포함) 반영
  Future<void> _grantPurchase(String reason) =>
      _setSource(ProEntitlementSource.purchase, reason: reason);

  /// Play 보유 조회로 구매 상태 맞추기: 보유 > 프로, 구매였는데 없음 > 무료(환불), 조회 실패 > 유지
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
      await _setSource(ProEntitlementSource.purchase, reason: 'owned_on_sync');
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
