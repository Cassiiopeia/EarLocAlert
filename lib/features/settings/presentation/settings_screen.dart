import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_resolver.dart';
import 'language_sheet.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/text/keep_all.dart';

/// 설정 화면이 보여줄 권한 한 줄 (이슈 #102)
///
/// **왜 권한 타입을 그대로 받지 않나** — settings 는 permission feature 를
/// 직접 import 하지 않는다 (docs/02-ARCHITECTURE.md 규칙 1). app 계층이
/// 권한 상태를 읽어 이 형태로 옮겨 내려준다.
class SettingsPermissionRow {
  const SettingsPermissionRow({
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  final String title;

  /// 없으면 무엇이 안 되는지. 권한 이름만으로는 아무도 켜지 않는다
  final String description;
  final bool granted;
  final VoidCallback onTap;
}

/// 잠금 화면 알람 상태 (이슈 #235)
enum LockScreenAlarmState {
  /// 허용됨 — 화면이 꺼져 있으면 잠금 화면 전체를 덮는다
  on,

  /// 아직 묻지 않았다 — 눌러서 허용을 묻는다
  notDetermined,

  /// 거부됐다 — OS 가 다시 묻지 않으므로 설정 앱으로 보낸다
  denied,

  /// iOS 26 미만 — 알림과 진동으로만 알린다는 안내만 보인다
  needsNewerOs,
}

/// 설정 화면이 보여줄 잠금 화면 알람 한 줄 (이슈 #235)
///
/// [SettingsPermissionRow] 와 같은 이유로 값으로 받는다 — AlarmKit 상태는
/// app 계층이 읽어 내려준다 (docs/02-ARCHITECTURE.md 규칙 1).
class SettingsLockScreenAlarm {
  const SettingsLockScreenAlarm({required this.state, this.onAction});

  final LockScreenAlarmState state;

  /// 허용 묻기 또는 설정 앱 열기. 할 일이 없는 상태면 null
  final VoidCallback? onAction;
}

/// 설정 화면 (이슈 #98, #102)
///
/// **왜 만들었나** — 홈 상태 바에 아이콘이 셋(알림음 크기·알림 미리보기·
/// 진단 기록) 늘어서면서 정작 중요한 감시 상태가 묻혔다. 상태 바는
/// "지금 감시 중인가"를 보여주는 곳이지 설정 모음이 아니다.
///
/// 평소에 쓸 일이 없는 것부터 여기로 내린다. 진단 기록은 문제가 생겼을
/// 때만 여는 화면이라 홈 최상단을 차지할 자리가 아니었다.
///
/// **권한 항목이 여기 있어야 하는 이유** (이슈 #102) — 알림 신뢰성 권한은
/// 온보딩의 선택 단계라 한 번 지나가면 다시 묻지 않는다. 그런데 그것을
/// 나중에 켤 자리가 앱 어디에도 없어서, 놓친 사용자는 "권한을 다 줬는데
/// 왜 알림 화면이 안 뜨는가"에 갇혔다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.onOpenVolumeSettings,
    required this.onOpenVibrationSettings,
    required this.onOpenDiagnostics,
    required this.language,
    required this.onLanguageChanged,
    required this.appVersion,
    this.onCheckUpdate,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    this.onOpenAdPrivacy,
    this.permissions = const [],
    this.lockScreenAlarm,
    this.onPreviewAlert,
    super.key,
  });

  final VoidCallback onOpenVolumeSettings;

  /// 진동 세기 (이슈 #103)
  final VoidCallback onOpenVibrationSettings;
  final VoidCallback onOpenDiagnostics;

  /// 지금 고른 앱 언어와 바꾸는 방법 (이슈 #163). app 계층이 값을 내려준다
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  /// 설치된 앱 버전과 업데이트 확인 (이슈 #179). app 계층이 값과 동작을 내려준다.
  /// 버전은 읽기 전에도 `-` 로 자리를 지킨다 — 줄이 깜빡이며 생기지 않게 한다
  final String appVersion;

  /// **null 이면 확인 버튼을 숨긴다** (이슈 #229). iOS 는 앱 내 업데이트가 없어
  /// 눌러도 아무 반응이 없었다 — 버전 글자만 남긴다
  final VoidCallback? onCheckUpdate;

  /// 이용약관·개인정보처리방침 (이슈 #188). 링크를 여는 일은 app 계층이 맡는다
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  /// 광고 동의 선택을 다시 여는 방법. **해당 지역이 아니면 null** 이고 항목을 숨긴다
  final VoidCallback? onOpenAdPrivacy;

  /// 알림이 확실히 도달하는 데 필요한 권한들 (이슈 #102)
  final List<SettingsPermissionRow> permissions;

  /// 잠금 화면 알람 (이슈 #235). **null 이면 줄을 숨긴다** — Android 에는 없다
  final SettingsLockScreenAlarm? lockScreenAlarm;

  /// 알림 흐름 수동 확인 (실기기 스파이크용).
  /// 지오펜스 실기기 검증이 끝나면 제거한다 (docs/11-ROADMAP.md).
  final VoidCallback? onPreviewAlert;

  /// 기기 언어를 따를 때 지금 어느 언어로 보이는지
  static String get _deviceLanguageName {
    final device = resolveAppLocale(
      AppLanguage.system,
      PlatformDispatcher.instance.locales,
    );
    return AppLanguage.parse(device.languageCode).nativeName ?? 'English';
  }

  String _languageSubtitle(BuildContext context) =>
      language == AppLanguage.system
      ? context.l10n.languageFollowDeviceHint(_deviceLanguageName)
      : language.nativeName!;

  Future<void> _openLanguage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showLanguageSheet(
      context,
      current: language,
      deviceLanguageName: _deviceLanguageName,
    );
    if (picked == null || picked == language) return;

    onLanguageChanged(picked);

    // **실수로 눌렀을 때 바로 되돌릴 수 있게 한다.** 문구는 화면이 아직 옛
    // 언어이므로 **바뀐 언어로** 직접 찾아 보여준다
    final strings = AppStrings.forLocale(
      resolveAppLocale(picked, PlatformDispatcher.instance.locales),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.languageChanged),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: strings.languageUndo,
            onPressed: () => onLanguageChanged(language),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            _SectionLabel(context.l10n.settingsSectionAlert),
            _SettingTile(
              icon: Icons.vibration_outlined,
              title: context.l10n.settingsVibrationTitle,
              subtitle: context.l10n.settingsVibrationSubtitle,
              onTap: onOpenVibrationSettings,
            ),
            _SettingTile(
              icon: Icons.tune_outlined,
              title: context.l10n.settingsVolumeTitle,
              subtitle: context.l10n.settingsVolumeSubtitle,
              onTap: onOpenVolumeSettings,
            ),
            // 화면이 꺼진 채 도착했을 때 무엇이 보이는지를 정하는 항목이라 알림 묶음에 둔다
            if (lockScreenAlarm != null)
              _LockScreenAlarmTile(alarm: lockScreenAlarm!),
            if (onPreviewAlert != null)
              _SettingTile(
                icon: Icons.notifications_active_outlined,
                title: context.l10n.settingsPreviewTitle,
                subtitle: context.l10n.settingsPreviewSubtitle,
                onTap: onPreviewAlert!,
              ),

            if (permissions.isNotEmpty) ...[
              _SectionLabel(context.l10n.settingsSectionReach),
              for (final row in permissions) _PermissionTile(row: row),
            ],

            // 언어는 "문제 해결" 이 아니라 일반 설정이다 (이슈 #229). 자주 바꾸는 값이
            // 아니라 알림 묶음 뒤에 둔다 (#163). 지구본 아이콘을 달아 문구를 못
            // 읽는 언어가 되어도 알아볼 수 있게 하고, 바꾼 직후에는 되돌리기가 뜬다
            _SectionLabel(context.l10n.settingsSectionGeneral),
            _SettingTile(
              icon: Icons.language_outlined,
              title: context.l10n.settingsLanguageTitle,
              subtitle: _languageSubtitle(context),
              onTap: () => _openLanguage(context),
            ),

            _SectionLabel(context.l10n.settingsSectionTroubleshoot),
            _SettingTile(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.settingsDiagnosticsTitle,
              subtitle: context.l10n.settingsDiagnosticsSubtitle,
              onTap: onOpenDiagnostics,
            ),

            // 약관과 방침은 스토어 심사 항목이고, 사용자가 찾는 자리다 (이슈 #188)
            _SectionLabel(context.l10n.settingsSectionAbout),
            _SettingTile(
              icon: Icons.description_outlined,
              title: context.l10n.settingsTermsTitle,
              onTap: onOpenTerms,
            ),
            _SettingTile(
              icon: Icons.privacy_tip_outlined,
              title: context.l10n.settingsPrivacyTitle,
              onTap: onOpenPrivacy,
            ),
            if (onOpenAdPrivacy != null)
              _SettingTile(
                icon: Icons.ads_click_outlined,
                title: context.l10n.settingsAdPrivacyTitle,
                subtitle: context.l10n.settingsAdPrivacySubtitle,
                onTap: onOpenAdPrivacy!,
              ),
            _SettingTile(
              icon: Icons.gavel_outlined,
              title: context.l10n.settingsLicensesTitle,
              onTap: () => showLicensePage(
                context: context,
                applicationName: context.l10n.appName,
              ),
            ),

            // 맨 끝의 읽기 전용 줄 (이슈 #179). 눌러서 업데이트를 바로 확인한다
            // 다른 줄과 같은 아이콘색·글자 스타일을 쓴다 — 이 줄만 밝게 튀었다
            ListTile(
              leading: const Icon(
                Icons.info_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                context.l10n.settingsVersionTitle,
                style: AppTypography.body,
              ),
              subtitle: Text(appVersion, style: AppTypography.caption),
              trailing: onCheckUpdate == null
                  ? null
                  : TextButton(
                      onPressed: onCheckUpdate,
                      child: Text(context.l10n.settingsVersionCheck),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 권한 한 줄 (이슈 #102)
///
/// 허용된 것도 **숨기지 않고 보여준다.** 무엇이 켜져 있고 무엇이 꺼져
/// 있는지가 한눈에 보여야 "알림이 왜 약한가"를 스스로 판단할 수 있다.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.row});

  final SettingsPermissionRow row;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final grantedColor = semantic?.statusActive ?? AppColors.textSecondary;

    return ListTile(
      leading: Icon(
        row.granted ? Icons.check_circle_outlined : Icons.error_outlined,
        color: row.granted ? grantedColor : AppColors.textSecondary,
      ),
      title: Text(row.title, style: AppTypography.body),
      subtitle: Text(
        context.keepAllText(
          row.granted
              ? context.l10n.settingsPermissionGranted
              : row.description,
        ),
        style: AppTypography.caption,
      ),
      // 이미 허용된 권한도 열 수 있게 둔다 — 사용자가 끄고 싶을 수 있다
      trailing: const Icon(Icons.chevron_right_outlined),
      onTap: row.onTap,
    );
  }
}

/// 잠금 화면 알람 한 줄 (이슈 #235)
///
/// iOS 26 미만에서도 숨기지 않는다 — "왜 내 아이폰은 화면을 덮지 않나"의 답이
/// 여기 있어야 한다. 그때는 누를 것이 없으니 버튼을 달지 않는다.
class _LockScreenAlarmTile extends StatelessWidget {
  const _LockScreenAlarmTile({required this.alarm});

  final SettingsLockScreenAlarm alarm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final onColor = semantic?.statusActive ?? AppColors.textSecondary;

    final subtitle = switch (alarm.state) {
      LockScreenAlarmState.on => l10n.settingsLockAlarmOn,
      LockScreenAlarmState.notDetermined => l10n.settingsLockAlarmNotDetermined,
      LockScreenAlarmState.denied => l10n.settingsLockAlarmDenied,
      LockScreenAlarmState.needsNewerOs => l10n.settingsLockAlarmNeedsNewerOs,
    };
    final actionLabel = switch (alarm.state) {
      LockScreenAlarmState.notDetermined => l10n.settingsLockAlarmAllow,
      LockScreenAlarmState.denied => l10n.settingsLockAlarmOpenSettings,
      LockScreenAlarmState.on || LockScreenAlarmState.needsNewerOs => null,
    };
    final on = alarm.state == LockScreenAlarmState.on;

    return ListTile(
      leading: Icon(
        on ? Icons.check_circle_outlined : Icons.alarm_outlined,
        color: on ? onColor : AppColors.textSecondary,
      ),
      title: Text(l10n.settingsLockAlarmTitle, style: AppTypography.body),
      subtitle: Text(
        context.keepAllText(subtitle),
        style: AppTypography.caption,
      ),
      trailing: actionLabel == null || alarm.onAction == null
          ? null
          : TextButton(onPressed: alarm.onAction, child: Text(actionLabel)),
      onTap: actionLabel == null ? null : alarm.onAction,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(text, style: AppTypography.caption),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTypography.body),
      subtitle: subtitle == null
          ? null
          : Text(context.keepAllText(subtitle!), style: AppTypography.caption),
      trailing: const Icon(Icons.chevron_right_outlined),
      onTap: onTap,
    );
  }
}
