import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/entitlement/pro_entitlement.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../data/pro_purchase_providers.dart';
import 'pro_purchase_record_controller.dart';

/// 구매 복원: Play 보유 조회 > 기록 저장 > 프로 반영 > 결과 안내 (#294)
/// 프로모션 코드로 받은 이용권도 Play 에는 구매로 남아 같은 방법으로 복원
/// 프로 안내 시트·이용권 정보 시트 공통
Future<void> restoreProPurchase(BuildContext context, WidgetRef ref) async {
  final service = ref.read(proPurchaseServiceProvider);
  final isOwned = await service.hasOwnedPurchase();
  Diagnostics.log('pro', 'restore result owned=$isOwned');
  if (isOwned ?? false) {
    await ref
        .read(proPurchaseRecordControllerProvider.notifier)
        .save(service.ownedRecord);
    await ref
        .read(featureAccessControllerProvider.notifier)
        .setSource(ProEntitlementSource.purchase, reason: 'restored');
  }
  if (!context.mounted) return;
  final l10n = context.l10n;
  context.showToast(switch (isOwned) {
    true => l10n.proRestoreDone,
    false => l10n.proRestoreNone,
    null => l10n.proProductUnavailable,
  });
}

/// 오퍼 코드 시트가 닫힌 뒤 조용히 보유 조회 > 있으면 프로 반영 + 완료 안내 (#305)
/// 코드를 안 쓰고 닫았을 수 있어 "구매 없음"은 안내하지 않음
Future<void> syncProAfterPromoCode(BuildContext context, WidgetRef ref) async {
  final service = ref.read(proPurchaseServiceProvider);
  final isOwned = await service.hasOwnedPurchase();
  Diagnostics.log('pro', 'promo code sync owned=$isOwned');
  if (!(isOwned ?? false)) return;
  await ref
      .read(proPurchaseRecordControllerProvider.notifier)
      .save(service.ownedRecord);
  await ref
      .read(featureAccessControllerProvider.notifier)
      .setSource(ProEntitlementSource.purchase, reason: 'promo_code');
  if (context.mounted) context.showToast(context.l10n.proPurchaseDone);
}
