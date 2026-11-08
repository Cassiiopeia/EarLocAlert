import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/ad_unit_ids.dart';
import '../../core/config/app_build_flavor.dart';
import '../../core/config/build_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/components/grouped_list_row.dart';
import '../../core/ui/components/grouped_list_section.dart';
import '../router.dart';
import 'dev_tools_action_runner.dart';
import 'dev_tools_actions.dart';

/// 개발자 도구 진단 탭 (#359): 빌드 정보, 지오펜스 재등록, 드라이브 동기화, 상태 복사, 진단 기록 이동
class DevToolsDiagnosticsTab extends ConsumerWidget {
  const DevToolsDiagnosticsTab({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(devToolsActionsProvider);
    return Column(
      children: [
        GroupedListSection(
          header: l10n.devToolsBuildSection,
          children: [
            GroupedListRow.value(
              title: l10n.devToolsBuildFlavor,
              valueText: AppBuildFlavor.label,
              onTap: null,
            ),
            GroupedListRow.value(
              title: l10n.devToolsBuildVersion,
              valueText: BuildInfo.label,
              onTap: null,
            ),
            GroupedListRow.value(
              title: l10n.devToolsAdUnit,
              valueText: AdUnitIds.usingTestIds
                  ? l10n.devToolsAdUnitTest
                  : l10n.devToolsAdUnitLive,
              onTap: null,
            ),
          ],
        ),
        GroupedListSection(
          header: l10n.devToolsWatchSection,
          children: [
            GroupedListRow.navigation(
              icon: Icons.my_location,
              title: l10n.devToolsGeofenceResync,
              onTap: () => runDevToolsAction(context, actions.resyncGeofences),
            ),
            GroupedListRow.navigation(
              icon: Icons.cloud_sync_outlined,
              title: l10n.devToolsCloudSyncNow,
              onTap: () => runDevToolsAction(
                context,
                actions.syncCloudNow,
                messageFor: (outcome) =>
                    l10n.devToolsCloudSyncResult(outcome.name),
              ),
            ),
          ],
        ),
        GroupedListSection(
          children: [
            GroupedListRow.navigation(
              icon: Icons.copy_all_outlined,
              title: l10n.devToolsCopyState,
              onTap: () => runDevToolsAction(
                context,
                () => _copyStateReport(actions),
                messageFor: (_) => l10n.devToolsCopied,
              ),
            ),
            GroupedListRow.navigation(
              icon: Icons.receipt_long_outlined,
              title: l10n.devToolsOpenDiagnostics,
              onTap: () {
                Navigator.of(context).pop();
                router.push(AppRoutes.diagnostics);
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copyStateReport(DevToolsActions actions) async {
    final report = await actions.collectStateReport();
    await Clipboard.setData(ClipboardData(text: report));
  }
}
