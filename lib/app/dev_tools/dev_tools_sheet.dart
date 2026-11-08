import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../core/ui/components/icon_label_segmented_control.dart';
import '../../core/ui/foundation/app_spacing.dart';
import 'dev_tools_diagnostics_tab.dart';
import 'dev_tools_plan_tab.dart';
import 'dev_tools_situation_tab.dart';

/// 개발자 도구 탭 3개: 등급, 상황, 진단
enum DevToolsTab { plan, situation, diagnostics }

/// 개발자 도구 시트 (#359): 탭 선택 > 탭 본문
/// 강제값은 앱 표시만 바꾸고 메모리에만 둠 (앱을 다시 켜면 꺼짐), 기록 초기화만 기기에 남음
class DevToolsSheet extends StatefulWidget {
  const DevToolsSheet({required this.router, super.key});

  final GoRouter router;

  @override
  State<DevToolsSheet> createState() => _DevToolsSheetState();
}

class _DevToolsSheetState extends State<DevToolsSheet> {
  // 화면 로컬 상태: 지금 보는 탭 (결정 069)
  DevToolsTab _selectedTab = DevToolsTab.plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.build_outlined,
      title: l10n.devToolsTitle,
      description: l10n.devToolsDescription,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconLabelSegmentedControl<DevToolsTab>(
            segments: [
              IconLabelSegment(
                value: DevToolsTab.plan,
                icon: Icons.workspace_premium_outlined,
                label: l10n.devToolsTabPlan,
              ),
              IconLabelSegment(
                value: DevToolsTab.situation,
                icon: Icons.science_outlined,
                label: l10n.devToolsTabSituation,
              ),
              IconLabelSegment(
                value: DevToolsTab.diagnostics,
                icon: Icons.monitor_heart_outlined,
                label: l10n.devToolsTabDiagnostics,
              ),
            ],
            selected: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (_selectedTab) {
            DevToolsTab.plan => const DevToolsPlanTab(),
            DevToolsTab.situation => DevToolsSituationTab(
              router: widget.router,
            ),
            DevToolsTab.diagnostics => DevToolsDiagnosticsTab(
              router: widget.router,
            ),
          },
        ],
      ),
    );
  }
}
