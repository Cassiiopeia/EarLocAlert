import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/components/status_bar_icons_following_theme.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/permission_providers.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_kind.dart';
import '../domain/permission_snapshot.dart';
import 'onboarding/onboarding_checklist_view.dart';
import 'onboarding/onboarding_ready_view.dart';
import 'permission_controller.dart';
import 'reliability_prompt_provider.dart';

/// 권한 온보딩 화면 (docs/06-UX.md, #376): 한 화면 체크리스트 > 준비 완료 > 첫 장소
///
/// 알림 화면 다음으로 중요한 화면이다 — 여기서 이탈하면 앱이 아무것도
/// 하지 못한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onFinished,
    this.onAddFirstPlace,
    this.onTestVibration,
  });

  /// 홈으로 (나중에 하기 · 재방문)
  final VoidCallback? onFinished;

  /// 준비 완료 > 첫 장소 등록 화면으로 (#376). null 이면 [onFinished]
  final VoidCallback? onAddFirstPlace;

  /// 진동 시험 (이슈 #237). 완료 화면에 카드로 보인다. **null 이면 숨긴다** —
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
  /// 끝낸 사용자는 곧장 홈으로 보낸다 (통행세 금지).
  bool _sawIncompleteStep = false;
  bool _autoFinished = false;

  /// 준비 완료 화면을 보이는가 (화면 안 전환 상태라 저장하지 않음)
  bool _isReadyShown = false;

  /// 이번 화면에서 요청까지 간 권한 (이슈 #211).
  ///
  /// 안내 화면에서 시스템 요청을 미룰 수 있으면 App Store 가 반려한다
  /// (5.1.1(iv)). 그래서 **한 번 요청한 뒤에만** 나가기를 보인다. 아예 없애지
  /// 않는 이유는 iOS 가 거부 뒤 창을 다시 띄우지 않을 때 사용자가 갇히기 때문이다 (#90).
  final Set<PermissionKind> _requestedKinds = {};

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
    // 설정 화면에서 권한을 바꾸고 돌아왔을 수 있다 > 다시 읽으면 줄이 체크로 바뀜
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionControllerProvider.notifier).refresh();
    }
  }

  /// 줄의 버튼: 영구 거부 > 설정 열기, 항상 위치인데 사용 중 위치가 없음 > 사용 중 위치부터, 그 외 > 그 권한 요청
  Future<void> _onRowPressed(
    PermissionSnapshot snapshot,
    PermissionKind kind,
  ) async {
    final controller = ref.read(permissionControllerProvider.notifier);
    final status = snapshot.statusOf(kind);
    Diagnostics.log(
      'permission',
      'onboarding row tapped kind=${kind.name} status=${status.name}',
    );
    if (status.isGranted) return;
    _requestedKinds.add(kind);
    if (status.needsSettings) {
      await controller.openSettings();
      return;
    }
    final isLocationMissing =
        kind == PermissionKind.backgroundLocation &&
        !snapshot.statusOf(PermissionKind.location).isGranted;
    await controller.requestOne(
      isLocationMissing ? PermissionKind.location : kind,
    );
  }

  /// 다음: 선택 권한 묶음을 본 것으로 기록(다시 권하지 않음) > 준비 완료 화면
  Future<void> _onNext() async {
    Diagnostics.log('permission', 'onboarding checklist next tapped');
    try {
      await ref
          .read(permissionControllerProvider.notifier)
          .skipReliabilityPrompt();
    } on Object catch (error) {
      // 기록 실패는 넘어간다 — 다음 실행에서 한 번 더 권하게 된다
      Diagnostics.log(
        'permission',
        'reliability seen save failed error=$error',
      );
    }
    if (mounted) setState(() => _isReadyShown = true);
  }

  void _finish(String reason) {
    Diagnostics.log('permission', 'onboarding finished reason=$reason');
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnapshot = ref.watch(permissionControllerProvider);
    final gate = ref.watch(permissionGateProvider);
    // 신뢰성 권한을 이미 권했는지 (이슈 #74)
    final asyncPromptSeen = ref.watch(reliabilityPromptProvider);

    // 앱바가 없는 화면 — 상태바 아이콘색을 직접 맞춘다 (이슈 #272)
    return StatusBarIconsFollowingTheme(
      child: Scaffold(
        body: SafeArea(
          child: asyncSnapshot.when(
            // 요청 중 잠깐 로딩이 되어도 체크리스트를 지우지 않는다 (줄 애니메이션 유지)
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const CenteredLoadingIndicator(),
            error: (error, _) => _ErrorView(
              onRetry: () =>
                  ref.read(permissionControllerProvider.notifier).refresh(),
            ),
            data: (snapshot) {
              // **읽지 못한 값을 추측하지 않는다** (이슈 #90) — 저장값 로딩 중이면 기다림
              if (!asyncPromptSeen.hasValue && asyncPromptSeen.isLoading) {
                return const CenteredLoadingIndicator();
              }
              final isPromptSeen = asyncPromptSeen.valueOrNull ?? false;
              final step = gate.nextStep(
                snapshot,
                reliabilityPromptSeen: isPromptSeen,
              );

              if (step != OnboardingStep.done) {
                _sawIncompleteStep = true;
              } else if (!_sawIncompleteStep && !_autoFinished) {
                // 재방문 사용자 — 곧장 홈으로
                _autoFinished = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _finish('already_granted');
                });
                return const CenteredLoadingIndicator();
              }

              final onTestVibration = widget.onTestVibration;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isReadyShown
                    ? OnboardingReadyView(
                        key: const ValueKey('ready'),
                        onAddFirstPlace: () {
                          Diagnostics.log(
                            'permission',
                            'onboarding finished reason=add_first_place',
                          );
                          (widget.onAddFirstPlace ?? widget.onFinished)?.call();
                        },
                        onLater: () => _finish('later'),
                        extra: onTestVibration == null
                            ? null
                            : _VibrationTestCard(onTest: onTestVibration),
                      )
                    : OnboardingChecklistView(
                        key: const ValueKey('checklist'),
                        snapshot: snapshot,
                        isAndroid: Platform.isAndroid,
                        onRowPressed: (kind) => _onRowPressed(snapshot, kind),
                        onNext: _onNext,
                        // **나갈 길은 남긴다** (A-12, #90) — 요청을 한 번 거친 뒤에만 (#211)
                        onSkip: _requestedKinds.isEmpty
                            ? null
                            : () => _finish('skipped'),
                      ),
              );
            },
          ),
        ),
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.vibration_outlined,
                size: AppIconSize.inline,
                color: context.appColors.accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.keepAllText(l10n.onboardingVibrationCardTitle),
                  style: context.appTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.keepAllText(l10n.onboardingVibrationCardBody),
            style: context.appTextStyles.caption,
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
            style: context.appTextStyles.screenTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.keepAllText(context.l10n.onboardingErrorHint),
            style: context.appTextStyles.caption,
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
