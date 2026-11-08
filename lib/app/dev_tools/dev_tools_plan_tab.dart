import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlement/feature_access_controller.dart';
import '../../core/entitlement/pro_entitlement.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/components/grouped_list_row.dart';
import '../../core/ui/components/grouped_list_section.dart';
import '../../features/pro/presentation/pro_purchase_record_controller.dart';

/// 등급 강제 선택지 3개: 실제 값(null), 무료, 프로
const _proOverrideChoices = <ProEntitlementSource?>[
  null,
  ProEntitlementSource.none,
  ProEntitlementSource.purchase,
];

/// 개발자 도구 등급 탭 (#359): 무료/프로 강제, 저장된 등급·화면 등급·장소 한도·구매 기록 표시
class DevToolsPlanTab extends ConsumerWidget {
  const DevToolsPlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final access = ref.watch(featureAccessControllerProvider);
    final controller = ref.read(featureAccessControllerProvider.notifier);
    final purchaseRecord = ref.watch(proPurchaseRecordControllerProvider).value;
    return Column(
      children: [
        GroupedListSection(
          header: l10n.devToolsProSection,
          children: [
            for (final choice in _proOverrideChoices)
              GroupedListRow.toggle(
                title: _choiceLabel(l10n, choice),
                value: controller.devOverrideSource == choice,
                onChanged: (_) => controller.setDevOverrideSource(choice),
              ),
          ],
        ),
        GroupedListSection(
          children: [
            GroupedListRow.value(
              title: l10n.devToolsProShown,
              valueText: _sourceLabel(l10n, access.source),
              onTap: null,
            ),
            GroupedListRow.value(
              title: l10n.devToolsProStored,
              valueText: _sourceLabel(l10n, controller.storedSource),
              onTap: null,
            ),
            GroupedListRow.value(
              title: l10n.devToolsPlaceLimit,
              valueText: '${access.placeLimit}',
              onTap: null,
            ),
            GroupedListRow.value(
              title: l10n.devToolsPurchaseOrder,
              valueText: purchaseRecord?.orderId ?? l10n.devToolsNone,
              onTap: null,
            ),
          ],
        ),
      ],
    );
  }

  String _choiceLabel(AppLocalizations l10n, ProEntitlementSource? choice) =>
      switch (choice) {
        null => l10n.devToolsProActual,
        ProEntitlementSource.none => l10n.devToolsProForceFree,
        ProEntitlementSource.purchase => l10n.devToolsProForcePro,
      };

  String _sourceLabel(AppLocalizations l10n, ProEntitlementSource source) =>
      source.isPro ? l10n.devToolsProPro : l10n.devToolsProFree;
}
