import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/text/keep_all.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_kind.dart';
import '../domain/permission_snapshot.dart';
import 'permission_controller.dart';
import 'permission_copy.dart';
import 'reliability_prompt_provider.dart';

/// 권한 온보딩 화면 (docs/06-UX.md)
///
/// 알림 화면 다음으로 중요한 화면이다 — 여기서 이탈하면 앱이 아무것도
/// 하지 못한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onFinished, this.onTestVibration});

  final VoidCallback? onFinished;

  /// 진동 시험 (이슈 #237). 완료 단계에 카드로 보인다. **null 이면 숨긴다** —
  /// iOS 에만 있다. 시험 흐름은 alert feature 것이라 app 계층이 넘겨준다 (규칙 1)
  final VoidCallback? onTestVibration;

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

  /// 이번 화면에서 시스템 권한 요청까지 간 단계 (이슈 #211).
  ///
  /// 안내 화면에서 시스템 요청을 미룰 수 있으면 App Store 가 반려한다
  /// (5.1.1(iv)). 그래서 시스템 창을 띄우는 단계는 **한 번 요청한 뒤에만**
  /// 나가기를 보인다. 아예 없애지 않는 이유는 iOS 가 거부 뒤 창을 다시
  /// 띄우지 않을 때 사용자가 화면에 갇히기 때문이다 (#90, A-12).
  /// 화면 재빌드는 요청 결과로 권한 상태가 바뀌며 일어나므로 setState 가 필요 없다.
  final Set<OnboardingStep> _requestedSteps = {};

  static bool _asksSystem(OnboardingStep step) => switch (step) {
    OnboardingStep.requestLocation ||
    OnboardingStep.requestBackgroundLocation ||
    OnboardingStep.requestNotification => true,
    OnboardingStep.requestAlertReliability ||
    OnboardingStep.openSettings ||
    OnboardingStep.done => false,
  };

  bool _canSkip(OnboardingStep step) {
    if (step == OnboardingStep.done) return false;
    return !_asksSystem(step) || _requestedSteps.contains(step);
  }

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
    final asyncPromptSeen = ref.watch(reliabilityPromptProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncSnapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            onRetry: () =>
                ref.read(permissionControllerProvider.notifier).refresh(),
          ),
          data: (snapshot) {
            // **읽지 못한 값을 추측하지 않는다** (이슈 #90).
            //
            // 권한 조회와 이 저장값은 각각 끝난다. 예전에는 저장값을 아직
            // 못 읽었으면 "이미 권했다"로 보고 넘어갔는데, 권한이 이미
            // 허용된 사용자는 권한 조회가 먼저 끝나므로 안내 화면이
            // 통째로 사라졌다. 기록도 남지 않아 다음 실행에서도 반복됐다.
            if (!asyncPromptSeen.hasValue && asyncPromptSeen.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            // 읽기에 실패했으면 "아직 안 권했다"로 본다 — 저장소 구현과
            // 같은 기본값이다. 한 번 더 묻는 쪽이 영영 안 묻는 쪽보다 낫다.
            final promptSeen = asyncPromptSeen.valueOrNull ?? false;

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
                Diagnostics.log(
                  'permission',
                  'onboarding tap step=${step.name}',
                );
                if (step == OnboardingStep.done) {
                  widget.onFinished?.call();
                  return;
                }
                _requestedSteps.add(step);
                await ref.read(permissionControllerProvider.notifier).proceed();
              },
              // **나갈 길은 남긴다** (A-12, 이슈 #90) — 단 시스템 권한 단계는
              // 요청을 한 번 거친 뒤에만 (이슈 #211, [_requestedSteps]).
              // 무엇이 안 되는지는 홈에서 상시 표시하고 켜러 갈 길을 준다.
              onSkip: _canSkip(step) ? () => _skip(step) : null,
              onTestVibration: step == OnboardingStep.done
                  ? widget.onTestVibration
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
    this.onTestVibration,
  });

  final OnboardingStep step;
  final PermissionSnapshot snapshot;
  final VoidCallback onAction;
  final VoidCallback? onSkip;

  /// 완료 단계의 진동 시험 카드 (이슈 #237)
  final VoidCallback? onTestVibration;

  @override
  Widget build(BuildContext context) {
    final copy = PermissionCopy.forStep(step, context.l10n);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // 설정 단계에서는 점이 "무엇이 빠졌는지"를 말해주지 못한다 (이슈 #217).
          // 점 세 개 중 어느 것이 왜 꺼져 있는지 알 수 없어서 점검 목록으로 바꾼다
          if (step != OnboardingStep.openSettings) ...[
            _ProgressDots(snapshot: snapshot),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            context.keepAllText(copy.title),
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(context.keepAllText(copy.body), style: AppTypography.body),
          if (step == OnboardingStep.openSettings) ...[
            const SizedBox(height: AppSpacing.md),
            _SettingsChecklist(snapshot: snapshot),
          ],
          if (copy.footnote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outlined,
                  size: AppIconSize.inline,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    context.keepAllText(copy.footnote!),
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
          if (onTestVibration != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _VibrationTestCard(onTest: onTestVibration!),
          ],
          const Spacer(),
          FilledButton(onPressed: onAction, child: Text(copy.actionLabel)),
          if (onSkip != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onSkip,
              child: Text(context.l10n.onboardingSkip),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 완료 단계의 진동 시험 카드 (이슈 #237)
///
/// **주 버튼(시작하기)을 뺏지 않는다** — 시험은 선택이라 보조 버튼으로 둔다.
/// iOS 는 진동 설정을 앱에 알려주지 않아, 꺼져 있으면 도착해도 아무 느낌이 없다.
/// 처음 쓰는 순간이 그것을 알아챌 가장 싼 때다.
class _VibrationTestCard extends StatelessWidget {
  const _VibrationTestCard({required this.onTest});

  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.vibration_outlined,
                size: AppIconSize.inline,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.keepAllText(l10n.onboardingVibrationCardTitle),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.keepAllText(l10n.onboardingVibrationCardBody),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onTest,
            child: Text(l10n.settingsVibrationTestTitle),
          ),
        ],
      ),
    );
  }
}

/// 설정에서 바꿔야 할 것을 이름과 고를 값으로 나열한다 (이슈 #217)
///
/// "권한을 켜주세요"만으로는 어느 권한을 어떻게 바꾸라는 건지 알 수 없다.
/// iOS 는 위치 권한을 바꾸면 앱이 종료될 수 있고, 설정 안의 뒤로 가기는 앱으로
/// 돌아오는 버튼이 아니다 — 돌아오는 길도 함께 알려준다.
class _SettingsChecklist extends StatelessWidget {
  const _SettingsChecklist({required this.snapshot});

  final PermissionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <String>[
      for (final kind in const PermissionGate().missing(snapshot))
        switch (kind) {
          PermissionKind.location => l10n.permissionSettingsLocationRow,
          PermissionKind.backgroundLocation =>
            Platform.isAndroid
                ? l10n.permissionSettingsBackgroundRowAndroid
                : l10n.permissionSettingsBackgroundRowIos,
          PermissionKind.notification => l10n.permissionSettingsNotificationRow,
          _ => '',
        },
    ].where((row) => row.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.radio_button_unchecked_outlined,
                  size: AppIconSize.inline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    context.keepAllText(row),
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outlined,
              size: AppIconSize.inline,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                context.keepAllText(
                  Platform.isAndroid
                      ? l10n.permissionSettingsReturnHintAndroid
                      : l10n.permissionSettingsReturnHintIos,
                ),
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      ],
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
          Text(
            context.keepAllText(context.l10n.onboardingErrorTitle),
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.keepAllText(context.l10n.onboardingErrorHint),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.onboardingRetry),
          ),
        ],
      ),
    );
  }
}
