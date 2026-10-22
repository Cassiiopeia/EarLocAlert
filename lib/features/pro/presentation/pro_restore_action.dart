import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/entitlement/pro_entitlement.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../data/pro_purchase_providers.dart';
import 'pro_purchase_record_controller.dart';

/// 구매 복원: Play 보유 조회 > 기록 저장 > 프로 반영(기존 사용자 혜택은 유지) > 결과 안내 (#294)
/// 프로 안내 시트·이용권 정보 시트 공통
Future<void> restoreProPurchase(BuildContext context, WidgetRef ref) async {
  final service = ref.read(proPurchaseServiceProvider);
  final isOwned = await service.hasOwnedPurchase();
  Diagnostics.log('pro', 'restore result owned=$isOwned');
  if (isOwned ?? false) {
    await ref
        .read(proPurchaseRecordControllerProvider.notifier)
        .save(service.ownedRecord);
    final access = ref.read(featureAccessControllerProvider);
    if (access.source != ProEntitlementSource.legacyUser) {
      await ref
          .read(featureAccessControllerProvider.notifier)
          .setSource(ProEntitlementSource.purchase, reason: 'restored');
    }
  }
  if (!context.mounted) return;
  final l10n = context.l10n;
  context.showToast(switch (isOwned) {
    true => l10n.proRestoreDone,
    false => l10n.proRestoreNone,
    null => l10n.proProductUnavailable,
  });
}
