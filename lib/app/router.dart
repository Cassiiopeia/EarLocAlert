import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../features/permission/presentation/onboarding_screen.dart';

/// 앱 라우팅 (docs/02-ARCHITECTURE.md)
///
/// `Navigator.push` 를 직접 호출하지 않는다 — 모든 화면 전환은
/// go_router 를 거친다.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
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
    ],
  );
}

/// 메인 화면은 아직 구현 전이다 (docs/11-ROADMAP.md Phase 1)
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
