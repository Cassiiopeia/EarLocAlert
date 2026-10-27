import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_resolver.dart';
import 'language_sheet.dart';
import 'theme_mode_sheet.dart';
import '../../../core/ui/components/grouped_list_row.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/ui/components/grouped_list_section.dart';
import '../../../core/ui/components/locked_content_blur.dart';
import '../../../core/ui/foundation/app_theme_preference.dart';

import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_semantic_colors.dart';
import '../../../core/ui/foundation/app_spacing.dart';

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

/// 설정 화면 — 값과 동작은 app 계층이 내려준다 (docs/02-ARCHITECTURE.md 규칙 1)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.onOpenVolumeSettings,
    required this.onOpenVibrationSettings,
    required this.onOpenVibrationPatternSettings,
    required this.onOpenDiagnostics,
    required this.onExportPlaces,
    required this.onImportPlaces,
    required this.onReportProblem,
    required this.language,
    required this.onLanguageChanged,
    required this.themePreference,
    required this.onThemeChanged,
    required this.appVersion,
    this.onCheckUpdate,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    this.onOpenAdPrivacy,
    this.permissions = const [],
    this.lockScreenAlarm,
    this.onOpenVibrationCheck,
    this.onOpenWatchGuide,
    this.planCard,
    this.isPlaceBackupLocked = false,
    this.onUnlockPro,
    super.key,
  });

  /// 맨 위 무료/프로 영역 (#294) — pro feature 위젯을 app 이 넣는다. 없으면 숨김
  final Widget? planCard;

  /// 무료라 장소 백업이 잠겼는가 (#294) — 흐리게 + 열기 버튼
  final bool isPlaceBackupLocked;

  /// 잠긴 기능을 눌렀을 때 — 프로 안내
  final VoidCallback? onUnlockPro;

  final VoidCallback onOpenVolumeSettings;

  /// 진동 세기 (이슈 #103)
  final VoidCallback onOpenVibrationSettings;

  /// 기본 진동 패턴 (#311)
  final VoidCallback onOpenVibrationPatternSettings;
  final VoidCallback onOpenDiagnostics;

  /// 장소 내보내기·불러오기 (이슈 #256). 구현은 places feature 에 있어 app 계층이 잇는다
  final VoidCallback onExportPlaces;
  final VoidCallback onImportPlaces;

  /// 문제 신고 메일 (이슈 #255). 시트는 diagnostics feature 에 있어 app 계층이 연결한다
  final VoidCallback onReportProblem;

  /// 지금 고른 앱 언어와 바꾸는 방법 (이슈 #163). app 계층이 값을 내려준다
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  /// 화면 모드 (이슈 #272). app 계층이 값을 내려주고, 고르면 바로 적용된다
  final AppThemePreference themePreference;
  final ValueChanged<AppThemePreference> onThemeChanged;

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

  /// 알림이 안 울릴 때 진동 점검 시트 (이슈 #301) — iPhone 만, Android 는 null
  final VoidCallback? onOpenVibrationCheck;

  /// 워치로 알림 받는 방법 안내 (이슈 #270). 시트는 app 계층이 플랫폼에 맞춰 연다.
  /// **null 이면 줄을 숨긴다**
  final VoidCallback? onOpenWatchGuide;

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
    showSnackBarWithActionButton(
      messenger,
      message: strings.languageChanged,
      actionLabel: strings.languageUndo,
      onActionPressed: () => onLanguageChanged(language),
      duration: const Duration(seconds: 8),
    );
  }

  Future<void> _openTheme(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final picked = await showThemeModeSheet(context, current: themePreference);
    if (picked == null || picked == themePreference) return;

    onThemeChanged(picked);

    // 실수로 눌렀을 때 바로 되돌릴 수 있게 한다 — 언어 설정과 같은 방식
    showSnackBarWithActionButton(
      messenger,
      message: l10n.themeChanged,
      actionLabel: l10n.themeUndo,
      onActionPressed: () => onThemeChanged(themePreference),
      duration: const Duration(seconds: 8),
    );
  }

  /// 장소 백업 두 줄. 무료면 한 덩어리로 흐리게 잠금 (#294)
  List<Widget> _backupRowsLockedIfFree(BuildContext context) {
    final rows = [
      GroupedListRow.navigation(
        icon: Icons.upload_file_outlined,
        title: context.l10n.settingsBackupExportTitle,
        subtitle: context.l10n.settingsBackupExportSubtitle,
        onTap: onExportPlaces,
      ),
      GroupedListRow.navigation(
        icon: Icons.file_open_outlined,
        title: context.l10n.settingsBackupImportTitle,
        subtitle: context.l10n.settingsBackupImportSubtitle,
        onTap: onImportPlaces,
      ),
    ];
    final onUnlock = onUnlockPro;
    if (!isPlaceBackupLocked || onUnlock == null) return rows;
    return [
      LockedContentBlur(
        caption: context.l10n.proLockedBackup,
        actionLabel: context.l10n.proUnlockAction,
        onUnlock: onUnlock,
        child: Column(children: rows),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: SafeArea(
        // iOS 설정 앱처럼 묶음마다 둥근 카드에 담는다 (이슈 #272)
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.lg,
          ),
          children: [
            ?planCard,
            GroupedListSection(
              header: context.l10n.settingsSectionAlert,
              children: [
                GroupedListRow.navigation(
                  icon: Icons.vibration_outlined,
                  title: context.l10n.settingsVibrationTitle,
                  subtitle: context.l10n.settingsVibrationSubtitle,
                  onTap: onOpenVibrationSettings,
                ),
                GroupedListRow.navigation(
                  icon: Icons.graphic_eq_outlined,
                  title: context.l10n.settingsVibrationPatternTitle,
                  subtitle: context.l10n.settingsVibrationPatternSubtitle,
                  onTap: onOpenVibrationPatternSettings,
                ),
                GroupedListRow.navigation(
                  icon: Icons.tune_outlined,
                  title: context.l10n.settingsVolumeTitle,
                  subtitle: context.l10n.settingsVolumeSubtitle,
                  onTap: onOpenVolumeSettings,
                ),
                // 화면이 꺼진 채 도착했을 때 무엇이 보이는지를 정하는 항목이라 알림 묶음에 둔다
                if (lockScreenAlarm != null)
                  _LockScreenAlarmTile(alarm: lockScreenAlarm!),
                // 화면이 꺼진 채 진동이 오는지는 시험해야만 안다 — 막혔을 때 찾아올 자리
                if (onOpenVibrationCheck != null)
                  GroupedListRow.navigation(
                    icon: Icons.vibration_outlined,
                    title: context.l10n.settingsVibrationCheckTitle,
                    subtitle: context.l10n.settingsVibrationCheckSubtitle,
                    onTap: onOpenVibrationCheck!,
                  ),
                // 폰 알림이 워치로 가려면 워치 쪽 토글을 켜야 한다 — 사용자가 알 길이 없어 안내한다
                if (onOpenWatchGuide != null)
                  GroupedListRow.navigation(
                    icon: Icons.watch_outlined,
                    title: context.l10n.settingsWatchTitle,
                    subtitle: context.l10n.settingsWatchSubtitle,
                    onTap: onOpenWatchGuide!,
                  ),
              ],
            ),

            if (permissions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              GroupedListSection(
                header: context.l10n.settingsSectionReach,
                children: [
                  for (final row in permissions) _PermissionTile(row: row),
                ],
              ),
            ],

            // 언어는 "문제 해결" 이 아니라 일반 설정이다 (이슈 #229). 자주 바꾸는 값이
            // 아니라 알림 묶음 뒤에 둔다 (#163). 지구본 아이콘을 달아 문구를 못
            // 읽는 언어가 되어도 알아볼 수 있게 하고, 바꾼 직후에는 되돌리기가 뜬다
            const SizedBox(height: AppSpacing.md),
            GroupedListSection(
              header: context.l10n.settingsSectionGeneral,
              children: [
                GroupedListRow.navigation(
                  icon: Icons.language_outlined,
                  title: context.l10n.settingsLanguageTitle,
                  subtitle: _languageSubtitle(context),
                  onTap: () => _openLanguage(context),
                ),
                GroupedListRow.navigation(
                  icon: Icons.contrast_outlined,
                  title: context.l10n.settingsThemeTitle,
                  subtitle: themePreferenceLabel(context.l10n, themePreference),
                  onTap: () => _openTheme(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            GroupedListSection(
              header: context.l10n.settingsSectionTroubleshoot,
              children: [
                GroupedListRow.navigation(
                  icon: Icons.receipt_long_outlined,
                  title: context.l10n.settingsDiagnosticsTitle,
                  subtitle: context.l10n.settingsDiagnosticsSubtitle,
                  onTap: onOpenDiagnostics,
                ),
                GroupedListRow.navigation(
                  icon: Icons.mail_outlined,
                  title: context.l10n.settingsReportTitle,
                  subtitle: context.l10n.settingsReportSubtitle,
                  onTap: onReportProblem,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            GroupedListSection(
              header: context.l10n.settingsSectionBackup,
              children: _backupRowsLockedIfFree(context),
            ),

            // 약관과 방침은 스토어 심사 항목이고, 사용자가 찾는 자리다 (이슈 #188)
            // 맨 끝의 버전 줄도 같은 묶음에 둔다 (이슈 #179)
            const SizedBox(height: AppSpacing.md),
            GroupedListSection(
              header: context.l10n.settingsSectionAbout,
              children: [
                GroupedListRow.navigation(
                  icon: Icons.description_outlined,
                  title: context.l10n.settingsTermsTitle,
                  onTap: onOpenTerms,
                ),
                GroupedListRow.navigation(
                  icon: Icons.privacy_tip_outlined,
                  title: context.l10n.settingsPrivacyTitle,
                  onTap: onOpenPrivacy,
                ),
                if (onOpenAdPrivacy != null)
                  GroupedListRow.navigation(
                    icon: Icons.ads_click_outlined,
                    title: context.l10n.settingsAdPrivacyTitle,
                    subtitle: context.l10n.settingsAdPrivacySubtitle,
                    onTap: onOpenAdPrivacy!,
                  ),
                GroupedListRow.navigation(
                  icon: Icons.gavel_outlined,
                  title: context.l10n.settingsLicensesTitle,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: context.l10n.appName,
                  ),
                ),
                // 맨 끝의 읽기 전용 줄 (이슈 #179). 눌러서 업데이트를 바로 확인한다
                // 다른 줄과 같은 아이콘색·글자 스타일을 쓴다 — 이 줄만 밝게 튀었다
                GroupedListRow.withTrailing(
                  icon: Icons.info_outlined,
                  title: context.l10n.settingsVersionTitle,
                  subtitle: appVersion,
                  keepSubtitleWordsTogether: false,
                  trailing: onCheckUpdate == null
                      ? null
                      : TextButton(
                          onPressed: onCheckUpdate,
                          child: Text(context.l10n.settingsVersionCheck),
                        ),
                ),
              ],
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
    final grantedColor =
        semantic?.statusActive ?? context.appColors.textSecondary;

    // 이미 허용된 권한도 열 수 있게 둔다 — 사용자가 끄고 싶을 수 있다
    return GroupedListRow.navigation(
      icon: row.granted ? Icons.check_circle_outlined : Icons.error_outlined,
      iconColor: row.granted ? grantedColor : null,
      title: row.title,
      subtitle: row.granted
          ? context.l10n.settingsPermissionGranted
          : row.description,
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
    final onColor = semantic?.statusActive ?? context.appColors.textSecondary;

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

    return GroupedListRow.withTrailing(
      icon: on ? Icons.check_circle_outlined : Icons.alarm_outlined,
      iconColor: on ? onColor : null,
      title: l10n.settingsLockAlarmTitle,
      subtitle: subtitle,
      trailing: actionLabel == null || alarm.onAction == null
          ? null
          : TextButton(onPressed: alarm.onAction, child: Text(actionLabel)),
      onTap: actionLabel == null ? null : alarm.onAction,
    );
  }
}
