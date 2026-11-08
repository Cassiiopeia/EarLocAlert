import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/alert_direction.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/components/grouped_list_row.dart';
import '../../core/ui/components/grouped_list_section.dart';
import '../../core/ui/feedback/app_feedback.dart';
import '../router.dart';
import 'dev_tools_action_runner.dart';
import 'dev_tools_actions.dart';

/// 개발자 도구 상황 탭 (#359): 알림 바로 울리기, 광고, 후기 요청, 온보딩 다시 보기
class DevToolsSituationTab extends ConsumerWidget {
  const DevToolsSituationTab({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(devToolsActionsProvider);
    return Column(
      children: [
        GroupedListSection(
          header: l10n.devToolsAlertSection,
          footer: l10n.devToolsAlertSubtitle,
          children: [
            GroupedListRow.navigation(
              icon: Icons.login,
              title: l10n.devToolsAlertArrive,
              onTap: () =>
                  _queueTestAlert(context, actions, AlertDirection.enter),
            ),
            GroupedListRow.navigation(
              icon: Icons.logout,
              title: l10n.devToolsAlertLeave,
              onTap: () =>
                  _queueTestAlert(context, actions, AlertDirection.exit),
            ),
          ],
        ),
        GroupedListSection(
          header: l10n.devToolsAdSection,
          children: [
            GroupedListRow.navigation(
              icon: Icons.ad_units_outlined,
              title: l10n.devToolsAdShowNow,
              onTap: () => runDevToolsAction(
                context,
                actions.showInterstitialNow,
                messageFor: (isShown) =>
                    isShown ? l10n.devToolsDone : l10n.devToolsAdNotReady,
              ),
            ),
            GroupedListRow.navigation(
              icon: Icons.restart_alt,
              title: l10n.devToolsAdReset,
              onTap: () => runDevToolsAction(context, actions.resetAdHistory),
            ),
          ],
        ),
        GroupedListSection(
          header: l10n.devToolsReviewSection,
          children: [
            GroupedListRow.navigation(
              icon: Icons.restart_alt,
              title: l10n.devToolsReviewReset,
              onTap: () =>
                  runDevToolsAction(context, actions.resetReviewRecords),
            ),
            GroupedListRow.navigation(
              icon: Icons.star_outline,
              title: l10n.devToolsReviewRequest,
              onTap: () => runDevToolsAction(
                context,
                actions.requestReviewNow,
                messageFor: (isRequested) => isRequested
                    ? l10n.devToolsDone
                    : l10n.devToolsReviewRequestFailed,
              ),
            ),
          ],
        ),
        GroupedListSection(
          header: l10n.devToolsOnboardingSection,
          children: [
            GroupedListRow.navigation(
              icon: Icons.replay,
              title: l10n.devToolsOnboardingReplay,
              onTap: () => _replayOnboarding(context, actions),
            ),
          ],
        ),
      ],
    );
  }

  /// 대기 알림 저장 > 시트 닫기 (알림 화면이 시트 뒤에 뜨지 않게)
  Future<void> _queueTestAlert(
    BuildContext context,
    DevToolsActions actions,
    AlertDirection direction,
  ) async {
    final l10n = context.l10n;
    final result = await actions.queueTestAlert(direction);
    if (!context.mounted) return;
    context.showToast(switch (result) {
      DevTestAlertResult.queued => l10n.devToolsAlertQueued,
      DevTestAlertResult.noPlace => l10n.devToolsAlertNoPlace,
    });
    if (result == DevTestAlertResult.queued) Navigator.of(context).pop();
  }

  Future<void> _replayOnboarding(
    BuildContext context,
    DevToolsActions actions,
  ) async {
    await runDevToolsAction(context, actions.resetOnboardingPrompt);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    router.go(AppRoutes.onboarding);
  }
}
