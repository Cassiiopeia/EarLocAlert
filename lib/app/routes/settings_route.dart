part of '../router.dart';

// 설정 라우트와 권한 줄 조립, 진동 시험·신뢰도 재권유

/// 진단 기록 라우트: 앱 상태 수집기를 화면에 값으로 넘김 (이슈 #290)
/// 도착 기록 (#313): 이력 + 장소 이름은 app 이 묶어 값으로 내려줌. 무료는 일부만
class _ArrivalHistoryRoute extends ConsumerWidget {
  const _ArrivalHistoryRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ArrivalHistoryScreen(
    records: ref.watch(arrivalHistoryProvider).valueOrNull,
    isLocked: !ref.watch(featureAccessControllerProvider).canViewFullHistory,
    onUnlockPro: () =>
        unawaited(showProOfferSheet(context, entryPoint: 'history')),
    onRefresh: () => ref.refresh(arrivalHistoryProvider.future),
  );
}

class _DiagnosticsRoute extends ConsumerWidget {
  const _DiagnosticsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) => DiagnosticsScreen(
    collectAppState: ref.read(appStateReporterProvider).collect,
  );
}

/// 설정 라우트 (이슈 #98, #102).
///
/// 알림음 크기·진단 기록·알림 미리보기가 여기 모인다. 홈 상태 바에
/// 아이콘이 셋 늘어서면서 정작 중요한 감시 상태가 묻혔기 때문이다.
///
/// 알림 도달 권한도 여기서 켠다 (이슈 #102) — permission feature 의
/// 상태를 읽어 **값으로** 내려준다. 화면은 그 feature 를 모른다
/// (docs/02-ARCHITECTURE.md 규칙 1).
class _SettingsRoute extends ConsumerStatefulWidget {
  const _SettingsRoute();

  @override
  ConsumerState<_SettingsRoute> createState() => _SettingsRouteState();
}

class _SettingsRouteState extends ConsumerState<_SettingsRoute>
    with WidgetsBindingObserver {
  /// 광고 동의 선택을 다시 열어야 하는 지역인가 (이슈 #188). 모르면 false 라 항목이 없다
  bool _adPrivacyRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAdPrivacyRequirement());
  }

  Future<void> _loadAdPrivacyRequirement() async {
    final required = await ref
        .read(adConsentProvider)
        .isPrivacyOptionsRequired();
    if (mounted && required) setState(() => _adPrivacyRequired = true);
  }

  /// 외부 브라우저로 연다. 열지 못하면 알려준다 — 아무 반응이 없으면 고장으로 읽는다
  Future<void> _openLink(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      Diagnostics.log('settings', 'open link threw uri=$uri error=$error');
    }
    if (!opened) {
      Diagnostics.log('settings', 'open link failed uri=$uri');
      if (mounted) context.showToast(context.l10n.settingsOpenLinkFailed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 신뢰성 권한은 전부 시스템 설정 화면으로 나갔다 온다 (이슈 #102).
    // 돌아온 시점에 다시 읽지 않으면 방금 켠 권한이 계속 꺼진 것으로
    // 보이고, 사용자는 자기가 켠 것이 반영되지 않았다고 판단한다.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(permissionControllerProvider.notifier).refresh());
      // 설정 앱에서 알람을 켜고 돌아왔을 수 있다 (이슈 #235)
      ref.invalidate(arrivalAlarmStatusProvider);
      // 알림·잠금 화면 표시도 마찬가지다 (이슈 #237)
      ref.invalidate(iosNotificationSettingsProvider);
    }
  }

  /// 설정 화면에 내려줄 잠금 화면 알람 줄 (이슈 #235). 읽는 중이면 줄을 숨긴다
  SettingsLockScreenAlarm? _lockScreenAlarm() {
    final status = ref.watch(arrivalAlarmStatusProvider).valueOrNull;
    if (status == null) return null;
    if (!status.supported) {
      return const SettingsLockScreenAlarm(
        state: LockScreenAlarmState.needsNewerOs,
      );
    }
    return switch (status.authorization) {
      ArrivalAlarmAuthorization.authorized => const SettingsLockScreenAlarm(
        state: LockScreenAlarmState.on,
      ),
      ArrivalAlarmAuthorization.denied => SettingsLockScreenAlarm(
        state: LockScreenAlarmState.denied,
        // 한 번 거부하면 OS 가 다시 묻지 않는다 — 설정 앱으로 보낸다
        onAction: () {
          Diagnostics.log('alarm', 'settings open tapped');
          unawaited(ref.read(arrivalAlarmPlatformProvider).openSettings());
        },
      ),
      ArrivalAlarmAuthorization.notDetermined ||
      ArrivalAlarmAuthorization.unsupported => SettingsLockScreenAlarm(
        state: LockScreenAlarmState.notDetermined,
        onAction: () async {
          await ref
              .read(arrivalAlarmCoordinatorProvider)
              .requestAuthorization('settings');
          ref.invalidate(arrivalAlarmStatusProvider);
        },
      ),
    };
  }

  /// 설정에서 직접 누른 업데이트 확인 (이슈 #179)
  ///
  /// 자동 확인(6시간 간격)과 달리 바로 확인한다. 결과는 세 가지다 — 받아 두었다면
  /// 재시작을 묻고, 받을 게 없으면 그렇다고 알리고, 알림이 울리는 중이면 아무것도
  /// 하지 않는다 (설정 화면은 알림 화면 뒤에 있어 사실상 오지 않는 경우다).
  Future<void> _checkUpdateNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final gate = ref.read(appUpdateGateProvider);
    final outcome = await gate.checkWhenIdle(
      alertActive: () => ref.read(activeAlertProvider) != null,
      force: true,
    );
    if (!mounted) return;
    switch (outcome) {
      case AppUpdateOutcome.downloaded:
        showSnackBarWithActionButton(
          messenger,
          message: l10n.appUpdateReady,
          actionLabel: l10n.appUpdateRestart,
          onActionPressed: () => unawaited(gate.install()),
          duration: const Duration(seconds: 15),
        );
      case AppUpdateOutcome.none:
        showToastOnMessenger(messenger, l10n.appUpdateNone);
      case AppUpdateOutcome.skippedAlertActive:
      case AppUpdateOutcome.skippedRecent:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(permissionControllerProvider).valueOrNull;

    return SettingsScreen(
      // 알림음 크기 (이슈 #86) — alert feature 의 시트를 app 이 잇는다
      onOpenVolumeSettings: () => showAlertVolumeSheet(context),
      // 진동 세기 (이슈 #103) — 이어폰이 없을 때 유일한 알림 수단이다
      onOpenVibrationSettings: () => showVibrationIntensitySheet(context),
      // 기본 진동 패턴 (#311) — 무료는 기본만, 나머지는 프로 안내
      onOpenVibrationPatternSettings: () => showDefaultVibrationPatternSheet(
        context,
        ref,
        onUnlockPro: () => unawaited(
          showProOfferSheet(context, entryPoint: 'vibration_pattern'),
        ),
      ),
      onOpenDiagnostics: () => context.push(AppRoutes.diagnostics),
      // 도착 기록 (#313)
      onOpenArrivalHistory: () => context.push(AppRoutes.arrivalHistory),
      // 장소 내보내기·불러오기 (이슈 #256)
      onExportPlaces: () => exportPlacesBackup(
        context,
        repository: ref.read(placeRepositoryProvider),
        appVersion: ref.read(appVersionProvider).valueOrNull ?? '-',
      ),
      onImportPlaces: () => importPlacesBackup(
        context,
        repository: ref.read(placeRepositoryProvider),
        maxPlaces: ref.read(featureAccessControllerProvider).placeLimit,
      ),
      // 자동 백업 (#314) — 수동 백업과 같은 잠금 묶음
      autoBackupSubtitle: autoBackupSubtitle(
        context.l10n,
        ref.watch(autoBackupStatusProvider).valueOrNull,
      ),
      onOpenAutoBackup: () => showAutoBackupSheet(
        context,
        onBackupNow: () => ref
            .read(autoBackupCoordinatorProvider)
            .runNow(reason: 'manual', force: true),
      ),
      // 무료/프로 (#294) — 맨 위 카드와 백업 잠금
      planCard: ProSettingsCard(
        placeCount: ref.watch(placeListProvider).valueOrNull?.length ?? 0,
      ),
      isPlaceBackupLocked: !ref
          .watch(featureAccessControllerProvider)
          .canUsePlaceBackup,
      onUnlockPro: () =>
          unawaited(showProOfferSheet(context, entryPoint: 'backup')),
      // 문제 신고 (이슈 #255) — 메일 앱을 열고 기록을 첨부한다
      onReportProblem: () => showBugReportSheet(
        context,
        // 메일·공유 플러그인 구현은 app 이 넣는다 (규칙 3)
        sender: BugReportSender(),
        appVersion: ref.read(appVersionProvider).valueOrNull ?? '-',
        // 첨부 보고서의 앱 상태 (이슈 #290)
        collectAppState: ref.read(appStateReporterProvider).collect,
      ),
      // 약관·방침 (이슈 #188) — 한국어는 한국어 문서, 나머지는 영어 문서
      onOpenTerms: () => _openLink(
        LegalLinks.terms(Localizations.localeOf(context).languageCode),
      ),
      onOpenPrivacy: () => _openLink(
        LegalLinks.privacy(Localizations.localeOf(context).languageCode),
      ),
      onOpenAdPrivacy: _adPrivacyRequired
          ? () => unawaited(ref.read(adConsentProvider).showPrivacyOptions())
          : null,
      // 앱 언어 (이슈 #163) — 고르면 바로 적용되고 저장된다
      // 화면 모드 (이슈 #272) — 고르면 바로 적용되고 저장된다
      themePreference: ref.watch(appThemeControllerProvider),
      onThemeChanged: (next) =>
          unawaited(ref.read(appThemeControllerProvider.notifier).select(next)),
      language: ref.watch(appLanguageControllerProvider),
      onLanguageChanged: (next) async {
        await ref.read(appLanguageControllerProvider.notifier).select(next);
        // 네이티브 알림 문구와 채널 이름도 바뀐 언어로 다시 만든다 (이슈 #164).
        // 알림은 앱이 죽어 있어도 Kotlin 이 만들어서 스스로는 언어 변경을 모른다
        unawaited(ref.read(geofenceRegistrationSyncProvider).refresh());
      },
      permissions: Platform.isIOS
          ? _iosNotificationRows(
              ref,
              ref.watch(iosNotificationSettingsProvider).valueOrNull,
              context.l10n,
            )
          : _permissionRows(ref, snapshot, context.l10n),
      // 잠금 화면 알람 (이슈 #235) — iOS 에만 있다. Android 는 전체 화면 알림 권한이 같은 일을 한다.
      // 스위치가 꺼져 있으면 줄을 숨김 (#252)
      lockScreenAlarm: Platform.isIOS && isLockScreenAlarmEnabled
          ? _lockScreenAlarm()
          : null,
      // 앱 버전과 업데이트 확인 (이슈 #179) — 읽기 실패는 `-` 로 보여준다
      appVersion: ref.watch(appVersionProvider).valueOrNull ?? '-',
      // 앱 내 업데이트가 없는 플랫폼(iOS)은 버튼을 숨긴다 (이슈 #229)
      onCheckUpdate: ref.read(appUpdateGateProvider).isSupported
          ? () => _checkUpdateNow(context)
          : null,
      // 워치로 알림 받는 방법 (이슈 #270) — 플랫폼마다 켜는 곳이 달라 문구가 갈린다
      // 알림이 안 울릴 때 진동 점검 (이슈 #301) — iPhone 만. Android 는 지금 경로로 잘 운다
      onOpenVibrationCheck: Platform.isIOS
          ? () => _runVibrationCheck(context, trigger: 'settings')
          : null,
      onOpenWatchGuide: () => showWatchGuideSheet(
        context,
        platform: Platform.isIOS
            ? WatchGuidePlatform.ios
            : WatchGuidePlatform.android,
      ),
    );
  }
}

/// 설정 화면에 내려줄 권한 목록 (이슈 #102).
///
/// **알림이 도달하는 데 관여하는 것만 넣는다.** 위치 권한은 감시 자체의
/// 전제라 홈 상태 알약이 담당하고, 여기 섞으면 "알림이 왜 약한가"라는
/// 질문의 답이 흐려진다.
///
/// 설명은 권한 이름이 아니라 **없으면 무엇이 안 되는지**를 쓴다. "다른 앱
/// 위에 표시"라고만 적힌 항목을 사용자가 켤 이유가 없다.
List<SettingsPermissionRow> _permissionRows(
  WidgetRef ref,
  PermissionSnapshot? snapshot,
  AppLocalizations l10n,
) {
  if (snapshot == null) return const [];

  // iOS 에는 배터리 최적화도 오버레이도 없다 — 항상 허용으로 보고되므로
  // 목록에 넣으면 켤 수 없는 항목만 늘어선다
  if (!Platform.isAndroid) return const [];

  void request(PermissionKind kind) {
    unawaited(ref.read(permissionControllerProvider.notifier).requestOne(kind));
  }

  return [
    SettingsPermissionRow(
      title: l10n.settingsPermNotifyTitle,
      description: l10n.settingsPermNotifyDesc,
      granted: snapshot.canNotify,
      onTap: () => request(PermissionKind.notification),
    ),
    SettingsPermissionRow(
      title: l10n.settingsPermBatteryTitle,
      description: l10n.settingsPermBatteryDesc,
      granted: snapshot.survivesDoze,
      onTap: () => request(PermissionKind.batteryOptimization),
    ),
    SettingsPermissionRow(
      title: l10n.settingsPermOverlayTitle,
      description: l10n.settingsPermOverlayDesc,
      granted: snapshot.canCoverScreen,
      onTap: () => request(PermissionKind.overlay),
    ),
    SettingsPermissionRow(
      title: l10n.settingsPermFullScreenTitle,
      description: l10n.settingsPermFullScreenDesc,
      granted: snapshot.canWakeScreen,
      onTap: () => request(PermissionKind.fullScreenIntent),
    ),
  ];
}

/// iOS 에서 앱이 읽을 수 있는 알림 설정 줄 (이슈 #237).
///
/// Android 의 권한 줄과 같은 자리·모양이다. 읽지 못했으면 줄을 숨긴다 — 모르는 값을
/// "꺼짐"으로 그리지 않는다. 고치는 곳은 둘 다 설정 앱의 이 앱 알림 페이지다.
List<SettingsPermissionRow> _iosNotificationRows(
  WidgetRef ref,
  IosNotificationSettings? settings,
  AppLocalizations l10n,
) {
  if (settings == null ||
      settings.authorization == IosNotificationAuthorization.unknown) {
    return const [];
  }
  void openSettings() {
    Diagnostics.log('permission', 'ios notification settings open tapped');
    unawaited(ref.read(permissionControllerProvider.notifier).openSettings());
  }

  return [
    SettingsPermissionRow(
      title: l10n.settingsPermNotifyTitle,
      description: l10n.settingsPermNotifyDesc,
      granted: !settings.isBlocked,
      onTap: openSettings,
    ),
    // 기기에 없는 항목이면 줄을 만들지 않는다
    if (settings.lockScreen != IosNotificationSetting.notSupported &&
        settings.lockScreen != IosNotificationSetting.unknown)
      SettingsPermissionRow(
        title: l10n.settingsLockScreenNotifyTitle,
        description: l10n.settingsLockScreenNotifyDesc,
        granted: settings.lockScreen == IosNotificationSetting.enabled,
        onTap: openSettings,
      ),
  ];
}

/// 진동 점검 시트를 연다 (이슈 #237, #301) — 시험 알림으로 화면이 꺼진 실제 경로를 시험
void _runVibrationCheck(BuildContext context, {required String trigger}) {
  unawaited(showIosVibrationCheckSheet(context, trigger: trigger));
}

/// iOS 홈 경고를 눌렀을 때 (이슈 #237, #301).
///
/// 알림 허용·잠금 화면·진동 중 하나라도 있으면 진동 점검 시트 — 앞의 둘은 시트가 읽고
/// 이 앱 알림 설정으로 바로 보낸다. 잠금 화면 알람만 남았으면 이 앱 설정 페이지.
void _fixIosReliability(
  BuildContext context,
  WidgetRef ref,
  List<ReliabilityGap> gaps,
) {
  final needsVibrationCheck = gaps.any(
    (gap) =>
        gap == ReliabilityGap.vibration ||
        gap == ReliabilityGap.notifications ||
        gap == ReliabilityGap.lockScreen,
  );
  Diagnostics.log(
    'home',
    'ios weak banner tapped gaps=[${gaps.map((gap) => gap.name).join(",")}] '
        'target=${needsVibrationCheck ? "vibration_check" : "system_settings"}',
  );
  if (needsVibrationCheck) {
    _runVibrationCheck(context, trigger: 'home_banner');
  } else if (gaps.any((gap) => gap.fixedInSystemSettings)) {
    unawaited(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(permissionControllerProvider.notifier).openSettings(),
    );
  }
}

/// 신뢰성 권한(#74)을 다시 권하고 온보딩으로 보낸다.
///
/// 기록 삭제가 실패해도 화면은 이동한다 — 그 경우 온보딩이 곧장 완료
/// 화면으로 넘어가지만, 사용자를 홈에 묶어두는 것보다는 낫다.
Future<void> _reofferReliability(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(reliabilityPromptProvider.notifier).reset();
  } on Object {
    // 아래 이동은 그대로 진행한다
  }
  if (context.mounted) context.go(AppRoutes.onboarding);
}
