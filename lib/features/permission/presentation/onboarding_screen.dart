import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_snapshot.dart';
import 'permission_controller.dart';
import 'permission_copy.dart';
import 'reliability_prompt_provider.dart';

/// 권한 온보딩 화면 (docs/06-UX.md)
///
/// 알림 화면 다음으로 중요한 화면이다 — 여기서 이탈하면 앱이 아무것도
/// 하지 못한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  /// 이번 세션에서 미완료 단계를 본 적이 있는가.
  ///
  /// **처음부터 done 이면 이 화면을 보여줄 이유가 없다** — 권한을 이미
  /// 끝낸 사용자가 앱을 켤 때마다 "준비되었습니다 → 시작하기"를 눌러야
  /// 한다면 그건 온보딩이 아니라 통행세다. 곧장 홈으로 보낸다.
  ///
  /// 반대로 이번 세션에서 권한을 밟아온 끝의 done 은 완료 확인 화면으로서
  /// 의미가 있으므로 그대로 보여준다.
  bool _sawIncompleteStep = false;
  bool _autoFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 사용자가 시스템 설정에서 권한을 바꾸고 돌아왔을 수 있다.
    // Android 의 "항상 허용"은 설정 화면에서만 켤 수 있으므로 필수다.
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionControllerProvider.notifier).refresh();
    }
  }

  /// 단계를 건너뛴다.
  ///
  /// 신뢰성 권한(#74)은 선택이므로 건너뛴 사실을 남겨 다시 묻지 않는다.
  /// 기록에 실패해도 화면 이동은 막지 않는다 — 다음 실행에서 한 번 더
  /// 묻는 것이 사용자를 온보딩에 가두는 것보다 낫다.
  Future<void> _skip(OnboardingStep step) async {
    if (step == OnboardingStep.requestAlertReliability) {
      try {
        await ref
            .read(permissionControllerProvider.notifier)
            .skipReliabilityPrompt();
      } on Object {
        // 기록 실패는 넘어간다
      }
      if (!mounted) return;
    }
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnapshot = ref.watch(permissionControllerProvider);
    final gate = ref.watch(permissionGateProvider);
    // 신뢰성 권한을 이미 권했는지 (이슈 #74).
    // 아직 못 읽었으면 "권한 적 있다"로 본다 — 잘못 판단해 온보딩을
    // 한 번 더 띄우는 것보다, 한 번 덜 띄우고 홈에서 안내하는 쪽이 낫다.
    final promptSeen = ref.watch(reliabilityPromptProvider).valueOrNull ?? true;

    return Scaffold(
      body: SafeArea(
        child: asyncSnapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            onRetry: () =>
                ref.read(permissionControllerProvider.notifier).refresh(),
          ),
          data: (snapshot) {
            final step = gate.nextStep(
              snapshot,
              reliabilityPromptSeen: promptSeen,
            );

            if (step != OnboardingStep.done) {
              _sawIncompleteStep = true;
            } else if (!_sawIncompleteStep && !_autoFinished) {
              // 재방문 사용자 — 완료 화면을 건너뛰고 곧장 홈으로
              _autoFinished = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.onFinished?.call();
              });
              return const Center(child: CircularProgressIndicator());
            }

            return _StepView(
              step: step,
              snapshot: snapshot,
              onAction: () async {
                if (step == OnboardingStep.done) {
                  widget.onFinished?.call();
                  return;
                }
                await ref.read(permissionControllerProvider.notifier).proceed();
              },
              // 영구 거부 상태에서도 앱을 열 수 있어야 한다 (A-12).
              // 온보딩에 사용자를 가둬두지 않는다.
              onSkip:
                  gate.canLeaveOnboarding(
                        snapshot,
                        reliabilityPromptSeen: promptSeen,
                      ) &&
                      step != OnboardingStep.done
                  ? () => _skip(step)
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.snapshot,
    required this.onAction,
    this.onSkip,
  });

  final OnboardingStep step;
  final PermissionSnapshot snapshot;
  final VoidCallback onAction;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final copy = PermissionCopy.forStep(step);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _ProgressDots(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
          Text(copy.title, style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.body, style: AppTypography.body),
          if (copy.footnote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(copy.footnote!, style: AppTypography.caption),
                ),
              ],
            ),
          ],
          const Spacer(),
          // 하단 전체 폭 pill 버튼 (docs/06-UX.md)
          FilledButton(onPressed: onAction, child: Text(copy.actionLabel)),
          if (onSkip != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSkip, child: const Text('나중에 하기')),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 진행 표시 — 남은 단계를 보여줘 이탈을 줄인다
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.snapshot});

  final PermissionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final kind in PermissionGate.requestOrder)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: snapshot.statusOf(kind).isGranted
                    ? AppColors.secondary
                    : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('권한 상태를 확인하지 못했습니다', style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          Text('잠시 후 다시 시도해주세요.', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
