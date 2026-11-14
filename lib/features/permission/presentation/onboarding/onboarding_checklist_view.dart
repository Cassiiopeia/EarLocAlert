import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/permission_gate.dart';
import '../../domain/permission_kind.dart';
import '../../domain/permission_snapshot.dart';
import 'onboarding_illustration.dart';
import 'onboarding_permission_row.dart';

part 'onboarding_checklist_parts.dart';

/// 권한 한 화면 체크리스트 (#376): 제목 · 단계별 안내 · 그림 · 필수 3줄 · 선택 묶음(Android) · 다음
/// 다음 할 줄을 강조하고, 허용되면 줄이 체크로 바뀌며 진행 링이 참
class OnboardingChecklistView extends StatelessWidget {
  const OnboardingChecklistView({
    required this.snapshot,
    required this.isAndroid,
    required this.onRowPressed,
    required this.onNext,
    this.onSkip,
    super.key,
  });

  final PermissionSnapshot snapshot;

  /// 항상 위치를 설정 화면에서 켜는가(Android) · 선택 묶음을 보이는가
  final bool isAndroid;

  /// 줄의 버튼: 요청하거나 설정을 연다 (어느 쪽인지는 화면 상태가 정함)
  final void Function(PermissionKind kind) onRowPressed;

  /// 필수 3개가 다 켜졌을 때만 눌림
  final VoidCallback onNext;

  /// 나가기 — 시스템 창을 한 번 거친 뒤에만 non-null (#211)
  final VoidCallback? onSkip;

  // 그림 한 변 (dp)
  static const double _illustrationSize = 168;

  /// 다음에 할 필수 권한. 다 켰으면 null
  PermissionKind? get _nextRequiredKind => PermissionGate.requestOrder
      .where((kind) => !snapshot.statusOf(kind).isGranted)
      .firstOrNull;

  int get _grantedRequiredCount => PermissionGate.requestOrder
      .where((kind) => snapshot.statusOf(kind).isGranted)
      .length;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nextKind = _nextRequiredKind;
    final isRequiredDone = nextKind == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  grantedCount: _grantedRequiredCount,
                  totalCount: PermissionGate.requestOrder.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                _GuideLine(text: _guideText(l10n, nextKind)),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: OnboardingIllustrationView(
                    illustration: _illustrationFor(nextKind),
                    size: _illustrationSize,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _SceneCaption(text: _sceneCaption(l10n, nextKind)),
                const SizedBox(height: AppSpacing.sm),
                for (final kind in PermissionGate.requestOrder)
                  _rowFor(context, kind, nextKind),
                if (isAndroid) _OptionalSection(rows: _optionalRows(context)),
                const SizedBox(height: AppSpacing.sm),
                // 항상 위치를 꺼리는 진짜 이유(추적)에 사실로 답함 (docs/06-UX.md 원칙 3)
                const _PrivacyNote(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: isRequiredDone ? onNext : null,
                child: Text(l10n.onboardingNext),
              ),
              if (onSkip != null)
                TextButton(onPressed: onSkip, child: Text(l10n.onboardingSkip)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowFor(
    BuildContext context,
    PermissionKind kind,
    PermissionKind? nextKind,
  ) {
    final l10n = context.l10n;
    final (icon, title, reason) = switch (kind) {
      PermissionKind.location => (
        Icons.place_outlined,
        l10n.onboardingRowLocation,
        l10n.onboardingRowLocationWhy,
      ),
      PermissionKind.backgroundLocation => (
        Icons.schedule_outlined,
        l10n.onboardingRowBackground,
        l10n.onboardingRowBackgroundWhy,
      ),
      _ => (
        Icons.notifications_none_rounded,
        l10n.onboardingRowNotification,
        l10n.onboardingRowNotificationWhy,
      ),
    };
    return OnboardingPermissionRow(
      icon: icon,
      title: title,
      reason: reason,
      rowState: _rowStateOf(kind, nextKind),
      // Android 의 항상 위치는 설정 화면에서만 켤 수 있음
      isOpenedInSettings:
          isAndroid && kind == PermissionKind.backgroundLocation,
      onPressed: () => onRowPressed(kind),
    );
  }

  List<Widget> _optionalRows(BuildContext context) {
    final l10n = context.l10n;
    return [
      for (final kind in PermissionGate.reliabilityOrder)
        OnboardingPermissionRow(
          icon: switch (kind) {
            PermissionKind.batteryOptimization => Icons.battery_saver_outlined,
            PermissionKind.overlay => Icons.layers_outlined,
            _ => Icons.fullscreen_rounded,
          },
          title: switch (kind) {
            PermissionKind.batteryOptimization => l10n.onboardingRowBattery,
            PermissionKind.overlay => l10n.onboardingRowOverlay,
            _ => l10n.onboardingRowFullScreen,
          },
          reason: switch (kind) {
            PermissionKind.batteryOptimization => l10n.onboardingRowBatteryWhy,
            PermissionKind.overlay => l10n.onboardingRowOverlayWhy,
            _ => l10n.onboardingRowFullScreenWhy,
          },
          rowState: snapshot.statusOf(kind).isGranted
              ? OnboardingRowState.granted
              : OnboardingRowState.pending,
          isOpenedInSettings: true,
          onPressed: () => onRowPressed(kind),
        ),
    ];
  }

  OnboardingRowState _rowStateOf(PermissionKind kind, PermissionKind? next) {
    final status = snapshot.statusOf(kind);
    if (status.isGranted) return OnboardingRowState.granted;
    if (status.needsSettings) return OnboardingRowState.blocked;
    return kind == next ? OnboardingRowState.next : OnboardingRowState.pending;
  }

  /// 단계별 안내 한 줄: 다음 권한 / 막힌 권한 / 끝
  String _guideText(AppLocalizations l10n, PermissionKind? nextKind) {
    if (nextKind == null) return l10n.onboardingGuideDone;
    if (snapshot.statusOf(nextKind).needsSettings) {
      return l10n.onboardingGuideBlocked;
    }
    return switch (nextKind) {
      PermissionKind.location => l10n.onboardingGuideLocation,
      PermissionKind.backgroundLocation =>
        isAndroid
            ? l10n.onboardingGuideBackgroundAndroid
            : l10n.onboardingGuideBackgroundIos,
      _ => l10n.onboardingGuideNotification,
    };
  }

  /// 다음 단계 > 왜 필요한지 보여 줄 그림 (다 켰으면 알림 장면 유지)
  OnboardingIllustration _illustrationFor(PermissionKind? nextKind) =>
      switch (nextKind) {
        PermissionKind.location => OnboardingIllustration.location,
        PermissionKind.backgroundLocation => OnboardingIllustration.background,
        _ => OnboardingIllustration.notification,
      };

  String _sceneCaption(AppLocalizations l10n, PermissionKind? nextKind) =>
      switch (nextKind) {
        PermissionKind.location => l10n.onboardingSceneLocation,
        PermissionKind.backgroundLocation => l10n.onboardingSceneBackground,
        _ => l10n.onboardingSceneNotification,
      };
}

/// 제목 + 오른쪽 진행 링 (허용한 필수 권한 수)
class _Header extends StatelessWidget {
  const _Header({required this.grantedCount, required this.totalCount});

  final int grantedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingChecklistTitle,
                style: context.appTextStyles.screenTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.keepAllText(l10n.onboardingChecklistSubtitle),
                style: context.appTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ProgressRing(done: grantedCount, total: totalCount),
      ],
    );
  }
}
