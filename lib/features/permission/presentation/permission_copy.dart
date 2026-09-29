import 'dart:io';

import '../../../core/l10n/l10n.dart';
import '../domain/permission_gate.dart';

/// 온보딩 단계별 안내 문구
///
/// **요청하기 전에 이유를 말한다** (docs/06-UX.md). 시스템 다이얼로그를
/// 바로 띄우지 않고 앱이 직접 그린 설명을 먼저 보여준다.
///
/// 이 문구는 그대로 **스토어 심사 자료가 된다** (docs/09-RELEASE.md).
class PermissionCopy {
  const PermissionCopy({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.footnote,
  });

  final String title;
  final String body;
  final String actionLabel;

  /// 위치를 전송하지 않는다는 사실 — 사용자가 "항상 위치"를 꺼리는
  /// 진짜 이유는 추적당하는 것이다. 사실을 말하는 것이 가장 효과적이다.
  final String? footnote;

  /// 단계별 문구. **같은 단계면 같은 문구**이며, 언어만 [l10n] 이 정한다.
  static PermissionCopy forStep(OnboardingStep step, AppLocalizations l10n) =>
      switch (step) {
        OnboardingStep.requestLocation => PermissionCopy(
          title: l10n.permissionLocationTitle,
          body: l10n.permissionLocationBody,
          actionLabel: l10n.permissionContinue,
          footnote: l10n.permissionLocalOnlyFootnote,
        ),
        OnboardingStep.requestBackgroundLocation => PermissionCopy(
          title: l10n.permissionBackgroundTitle,
          body: l10n.permissionBackgroundBody,
          actionLabel: Platform.isAndroid
              ? l10n.permissionBackgroundActionAndroid
              : l10n.permissionContinue,
          footnote: Platform.isAndroid
              ? l10n.permissionBackgroundFootnoteAndroid
              : l10n.permissionLocalOnlyFootnote,
        ),
        OnboardingStep.requestNotification => PermissionCopy(
          title: l10n.permissionNotificationTitle,
          body: l10n.permissionNotificationBody,
          actionLabel: l10n.permissionContinue,
        ),
        // 이슈 #74 — 이 셋이 없으면 앱을 열어두지 않은 동안 알림이 약해진다.
        // 필수는 아니지만 왜 필요한지를 증상으로 설명한다.
        OnboardingStep.requestAlertReliability => PermissionCopy(
          title: l10n.permissionReliabilityTitle,
          body: l10n.permissionReliabilityBody,
          actionLabel: l10n.permissionReliabilityAction,
          // 이전 문구는 "건너뛰어도 그대로 동작한다"였는데 사실과 다르다
          // (이슈 #84). 이 권한들이 없으면 알림 화면이 저절로 뜨지 않아,
          // 진동이 울리는데 끄려면 알림을 눌러 앱을 열어야 한다. 대가를
          // 숨기면 사용자는 나중에 오작동으로 받아들인다.
          footnote: l10n.permissionReliabilityFootnote,
        ),
        OnboardingStep.openSettings => PermissionCopy(
          title: l10n.permissionOpenSettingsTitle,
          body: l10n.permissionOpenSettingsBody,
          actionLabel: l10n.permissionOpenSettingsAction,
        ),
        OnboardingStep.done => PermissionCopy(
          title: l10n.permissionDoneTitle,
          body: l10n.permissionDoneBody,
          actionLabel: l10n.permissionDoneAction,
        ),
      };
}
