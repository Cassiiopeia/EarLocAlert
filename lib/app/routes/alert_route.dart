part of '../router.dart';

// 알림 화면 라우트 — 해제는 광고를 기다리지 않는다

/// 알림 화면 라우트.
///
/// 해제 시 **광고를 기다리지 않고** 곧바로 홈으로 간다
/// (docs/02-ARCHITECTURE.md 규칙 4, 결정 056). 흐름은 [AlertDismissFlow] 가 정한다.
class _AlertRoute extends ConsumerWidget {
  const _AlertRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeAlertProvider);

    if (session == null) {
      // 세션이 없는 상태로 들어왔다 — 홈으로 돌린다.
      // 해제 직후에도 세션이 비어 여기로 온다. 그때는 해제 흐름이 이미 홈으로
      // 옮겼으므로 덮어쓰면 안 된다 (이슈 #222).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final path = GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.uri.path;
        if (shouldLeaveEmptyAlertRoute(path)) {
          context.go(AppRoutes.home);
        } else {
          Diagnostics.log('alert', 'empty alert redirect skipped path=$path');
        }
      });
      return alwaysDarkEmptyAlertPlaceholder();
    }

    // 알림 화면은 화면 모드와 무관하게 다크다 (이슈 #272)
    return wrapWithAlwaysDarkAlertTheme(
      AlertScreen(
        session: session,
        soundFailed: ref.read(activeAlertProvider.notifier).soundFailed,
        onDismiss: () {
          // 이 화면은 곧 사라진다 — 광고는 그 뒤에 시도되므로 화면의 ref·context 가
          // 아니라 앱 수명의 라우터·컨테이너를 붙잡는다
          final router = GoRouter.of(context);
          final container = ProviderScope.containerOf(context, listen: false);
          unawaited(
            AlertDismissFlow(
              dismiss: () =>
                  container.read(activeAlertProvider.notifier).dismiss(),
              isRinging: () => container.read(activeAlertProvider) != null,
              goHome: () => router.go(AppRoutes.home),
              // 옮겨 간 화면 위에 띄운다 — 알림 화면의 context 는 이미 없다
              showDismissedToast: () =>
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final target =
                        router.routerDelegate.navigatorKey.currentContext;
                    if (target == null || !target.mounted) return;
                    target.showToast(target.l10n.alertDismissedTitle);
                  }),
              tryShowAd: () => _tryShowAd(container),
            ).run(),
          );
        },
      ),
    );
  }

  Future<void> _tryShowAd(ProviderContainer container) async {
    final coordinator = await container.read(alertAdCoordinatorProvider.future);
    await coordinator.onAlertDismissed(now: DateTime.now().toUtc());
  }
}

/// 세션 없는 알림 화면에서 홈으로 돌릴지 (이슈 #222).
///
/// 아직 알림 화면에 머물러 있을 때만 돌린다. 해제 흐름이 이미 홈으로 옮겼다면
/// 그 화면을 지켜야 한다 — 덮어쓰면 화면 전환이 두 번 일어난다.
@visibleForTesting
bool shouldLeaveEmptyAlertRoute(String currentPath) =>
    currentPath == AppRoutes.alert;
