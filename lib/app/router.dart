import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/alert_direction.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../features/alert/domain/alert_controller.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/alert/presentation/alert_dismissed_screen.dart';
import '../features/alert/presentation/alert_screen.dart';
import '../features/permission/presentation/onboarding_screen.dart';

/// 앱 라우팅 (docs/02-ARCHITECTURE.md)
///
/// `Navigator.push` 를 직접 호출하지 않는다 — 모든 화면 전환은
/// go_router 를 거친다.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const alert = '/alert';
  static const alertDismissed = '/alert/dismissed';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) =>
            OnboardingScreen(onFinished: () => context.go(AppRoutes.home)),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const _HomePlaceholder(),
      ),
      GoRoute(
        path: AppRoutes.alert,
        builder: (context, state) => const _AlertRoute(),
      ),
      GoRoute(
        path: AppRoutes.alertDismissed,
        builder: (context, state) => AlertDismissedScreen(
          placeName: state.extra as String? ?? '',
          onContinue: () => context.go(AppRoutes.home),
        ),
      ),
    ],
  );
}

/// 알림 화면 라우트.
///
/// 해제 시 **광고를 기다리지 않고** 곧바로 화면을 전환한다
/// (docs/02-ARCHITECTURE.md 규칙 4).
class _AlertRoute extends ConsumerWidget {
  const _AlertRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeAlertProvider);

    if (session == null) {
      // 세션이 없는 상태로 들어왔다 — 홈으로 돌린다
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return AlertScreen(
      session: session,
      onDismiss: () async {
        final placeName = session.placeName;
        final dismissed = await ref
            .read(activeAlertProvider.notifier)
            .dismiss();
        if (!context.mounted) return;

        // 대기 중이던 다른 장소 알림이 이어서 울리면 이 화면에 머문다
        if (ref.read(activeAlertProvider) != null) return;

        if (dismissed != null) {
          context.go(AppRoutes.alertDismissed, extra: placeName);
        } else {
          context.go(AppRoutes.home);
        }
      },
    );
  }
}

/// 메인 화면은 아직 구현 전이다 (docs/11-ROADMAP.md Phase 1)
class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64),
            const SizedBox(height: AppSpacing.sm),
            Text('EarLocAlert', style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.xs),
            Text('지도 화면 준비 중', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
            // 백그라운드 감시 연결 전까지 알림 흐름을 확인하는 수단.
            // 지오펜스 연동(S-1 스파이크 이후)이 끝나면 제거한다.
            OutlinedButton(
              onPressed: () async {
                await ref
                    .read(activeAlertProvider.notifier)
                    .fire(
                      AlertRequest(
                        placeId: 'preview',
                        placeName: '테스트 장소',
                        direction: AlertDirection.enter,
                        soundEnabled: true,
                        occurredAt: DateTime.now().toUtc(),
                      ),
                    );
                if (context.mounted) context.go(AppRoutes.alert);
              },
              child: const Text('알림 화면 미리보기'),
            ),
          ],
        ),
      ),
    );
  }
}
