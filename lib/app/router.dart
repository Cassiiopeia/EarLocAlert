import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/di/providers.dart';
import '../core/diagnostics/diagnostics.dart';
import '../core/legal/legal_links.dart';
import '../core/widgets/app_feedback.dart';
import '../core/domain/sound_preset_label.dart';
import '../core/l10n/app_language_controller.dart';
import 'geofence_providers.dart';
import '../core/l10n/l10n.dart';
import '../core/domain/alert_direction.dart';
import '../core/domain/alert_sound.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/domain/alert_controller.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/alert/presentation/alert_screen.dart';
import '../features/alert/presentation/alert_volume_sheet.dart';
import '../features/alert/presentation/vibration_intensity_sheet.dart';
import '../features/permission/domain/permission_kind.dart';
import '../features/permission/domain/permission_snapshot.dart';
import '../features/permission/presentation/onboarding_screen.dart';
import '../features/permission/presentation/permission_controller.dart';
import '../features/permission/presentation/reliability_prompt_provider.dart';
import '../features/places/domain/alert_place.dart';
import '../features/places/presentation/place_form_screen.dart';
import '../features/places/presentation/place_map_home_screen.dart';
import '../features/places/presentation/place_map_picker_screen.dart';
import '../features/diagnostics/presentation/diagnostics_screen.dart';
import '../features/places/presentation/place_search_provider.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sounds/presentation/sound_picker_sheet.dart';
import '../features/app_update/domain/app_updater.dart';
import '../features/app_update/presentation/app_update_providers.dart';
import 'alert_dismiss_flow.dart';
import 'app_version_provider.dart';
import 'arrival_alarm_providers.dart';
import 'background/arrival_alarm_channel.dart';
import 'ad_banner_frame.dart';
import 'home_status_provider.dart';

/// 앱 라우팅 (docs/02-ARCHITECTURE.md)
///
/// `Navigator.push` 를 직접 호출하지 않는다 — 모든 화면 전환은
/// go_router 를 거친다.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const alert = '/alert';
  static const placeNew = '/places/new';
  static const placeEdit = '/places/edit';
  static const placeMap = '/places/map';

  /// 진단 기록 (이슈 #95) — 백그라운드 문제를 확인하는 유일한 창구
  static const diagnostics = '/diagnostics';

  /// 설정 (이슈 #98) — 알림음 크기·진단 기록이 여기 모인다
  static const settings = '/settings';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onFinished: () {
            // 잠금 화면 알람 권한은 온보딩이 끝난 뒤 한 번만 묻는다 (이슈 #235).
            // 다시 온 사용자도 여기를 지나므로 앱 시작 시 묻는 자리이기도 하다 —
            // 이미 정해졌으면 아무것도 하지 않는다. 위치 권한 대화상자와 겹치지 않게 뒤에 둔다
            if (Platform.isIOS) {
              unawaited(
                ProviderScope.containerOf(context, listen: false)
                    .read(arrivalAlarmCoordinatorProvider)
                    .requestIfUndetermined('onboarding_finished'),
              );
            }
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const AdBannerFrame(child: _HomeRoute()),
      ),
      GoRoute(
        path: AppRoutes.placeNew,
        builder: (context, state) =>
            const AdBannerFrame(child: _PlaceFormRoute()),
      ),
      GoRoute(
        path: AppRoutes.placeEdit,
        builder: (context, state) => AdBannerFrame(
          child: _PlaceFormRoute(existing: state.extra as AlertPlace?),
        ),
      ),
      GoRoute(
        path: AppRoutes.placeMap,
        builder: (context, state) =>
            _MapPickerRoute(args: state.extra! as MapPickArgs),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) =>
            const AdBannerFrame(child: _SettingsRoute()),
      ),
      GoRoute(
        path: AppRoutes.alert,
        builder: (context, state) => const _AlertRoute(),
      ),
    ],
  );
}

/// 지도 위치 선택 라우트 — 검색 서비스를 조립해 내려준다 (issue #72).
class _MapPickerRoute extends ConsumerWidget {
  const _MapPickerRoute({required this.args});

  final MapPickArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceMapPickerScreen(
      args: args,
      searchService: ref.watch(placeSearchServiceProvider),
      onPicked: (result) => context.pop(result),
    );
  }
}

/// 지도 화면을 열고 선택 결과를 기다린다.
///
/// 폼은 `Navigator`·`GoRouter` 를 직접 만지지 않는다 — 화면 전환은 전부
/// 여기서 조율한다 (docs/02-ARCHITECTURE.md).
/// 장소 등록·편집 화면의 배선 (이슈 #121)
///
/// **폼이 `sounds` 를 직접 import 하지 않게 하는 자리다** (규칙 1).
/// 알림음 시트를 열고 이름을 조회하는 일을 여기서 이어붙인다 —
/// 설정 화면(`_SettingsRoute`)이 시트와 provider 를 잇는 것과 같은 방식이다.
class _PlaceFormRoute extends ConsumerWidget {
  const _PlaceFormRoute({this.existing});

  /// null 이면 신규 등록
  final AlertPlace? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceFormScreen(
      existing: existing,
      onSaved: () => _leaveForm(context),
      onDeleted: () => _leaveForm(context),
      onPickOnMap: (args) => _pickOnMap(context, args),
      onPickSound: (current) => showSoundPickerSheet(context, current: current),
      onDescribeSound: (sound) => _describeSound(ref, sound, context.l10n),
    );
  }
}

/// 알림음의 표시 이름.
///
/// 사용자 음원은 저장소에서 파일명을 읽는다. **행이 없으면 지워진
/// 음원이다** — 그 사실을 숨기지 않는다. 실제 알림은 기본음으로 울리므로
/// 소리가 안 나지는 않지만, 사용자는 자기가 고른 것이 사라졌음을
/// 알아야 다시 고를 수 있다.
Future<String> _describeSound(
  WidgetRef ref,
  AlertSound sound,
  AppLocalizations l10n,
) async {
  switch (sound) {
    case PresetSound(:final preset):
      return preset.localizedLabel(l10n);
    case CustomSoundRef(:final id):
      final found = await ref.read(customSoundRepositoryProvider).findById(id);
      return found?.displayName ?? l10n.routeDeletedSound;
  }
}

Future<MapPickResult?> _pickOnMap(BuildContext context, MapPickArgs args) {
  return context.push<MapPickResult>(AppRoutes.placeMap, extra: args);
}

/// 장소 폼에서 빠져나온다 (이슈 #97).
///
/// 홈에서 `push` 로 들어왔으면 `pop` 이 자연스럽다 — 스택이 유지되어
/// 뒤로가기 동작과 결과가 같다.
///
/// **`canPop` 을 확인하는 이유** — 딥링크나 알림 탭처럼 스택 없이 이 화면에
/// 바로 진입하는 경로가 있다. 그때 `pop` 하면 갈 곳이 없어 아무 일도
/// 일어나지 않고, 사용자는 저장했는데 화면이 그대로인 상태에 갇힌다.
/// 그것이 정확히 이 이슈에서 고치려는 증상이다.
void _leaveForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// 설정의 알림 미리보기가 쓰는 장소 id. 실제 장소 id 는 uuid 라 겹치지 않는다
@visibleForTesting
const previewPlaceId = 'preview';

/// 세션 없는 알림 화면에서 홈으로 돌릴지 (이슈 #222).
///
/// 아직 알림 화면에 머물러 있을 때만 돌린다. 해제 흐름이 이미 홈(미리보기면
/// 설정)으로 옮겼다면 그 화면을 지켜야 한다 — 덮어쓰면 설정으로 돌아가던
/// 미리보기가 홈에 떨어진다.
@visibleForTesting
bool shouldLeaveEmptyAlertRoute(String currentPath) =>
    currentPath == AppRoutes.alert;

/// 알림 화면 라우트.
///
/// 해제 시 **광고를 기다리지 않고** 곧바로 홈으로 간다
/// (docs/02-ARCHITECTURE.md 규칙 4, 결정 056). 흐름은 [AlertDismissFlow] 가 정한다.
class _AlertRoute extends ConsumerWidget {
  const _AlertRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeAlertProvider);

    if (session == null) {
      // 세션이 없는 상태로 들어왔다 — 홈으로 돌린다.
      // 해제 직후에도 세션이 비어 여기로 온다. 그때는 해제 흐름이 이미 홈으로
      // 옮겼으므로 덮어쓰면 안 된다 (이슈 #222).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final path = GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.uri.path;
        if (shouldLeaveEmptyAlertRoute(path)) {
          context.go(AppRoutes.home);
        } else {
          Diagnostics.log('alert', 'empty alert redirect skipped path=$path');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return AlertScreen(
      session: session,
      soundFailed: ref.read(activeAlertProvider.notifier).soundFailed,
      onDismiss: () {
        // 이 화면은 곧 사라진다 — 광고는 그 뒤에 시도되므로 화면의 ref·context 가
        // 아니라 앱 수명의 라우터·컨테이너를 붙잡는다
        final router = GoRouter.of(context);
        final container = ProviderScope.containerOf(context, listen: false);
        unawaited(
          AlertDismissFlow(
            dismiss: () =>
                container.read(activeAlertProvider.notifier).dismiss(),
            isRinging: () => container.read(activeAlertProvider) != null,
            goHome: () => router.go(AppRoutes.home),
            // `go` 로 설정만 띄우면 뒤로 갈 곳이 없다 — 홈이 세워진 뒤(다음
            // 프레임)에 push 해야 스택이 [홈, 설정] 으로 잡힌다 (이슈 #229)
            returnToSettings: () =>
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => unawaited(router.push(AppRoutes.settings)),
                ),
            // 옮겨 간 화면 위에 띄운다 — 알림 화면의 context 는 이미 없다
            showDismissedToast: () =>
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final target =
                      router.routerDelegate.navigatorKey.currentContext;
                  if (target == null || !target.mounted) return;
                  target.showToast(target.l10n.alertDismissedTitle);
                }),
            tryShowAd: () => _tryShowAd(container),
          ).run(fromPreview: session.placeId == previewPlaceId),
        );
      },
    );
  }

  Future<void> _tryShowAd(ProviderContainer container) async {
    final coordinator = await container.read(alertAdCoordinatorProvider.future);
    await coordinator.onAlertDismissed(now: DateTime.now().toUtc());
  }
}

/// 메인 화면 — 지도 위에 등록 장소와 감시 상태를 얹는다 (docs/06-UX.md).
///
/// 감시·이어폰 상태는 geofence·alert feature 소유라 여기서 읽어 **값으로**
/// 내려준다. 화면은 어느 feature 도 직접 import 하지 않는다
/// (docs/02-ARCHITECTURE.md 규칙 1).
class _HomeRoute extends ConsumerWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(homeStatusProvider).valueOrNull ?? HomeStatus.unknown;

    return PlaceMapHomeScreen(
      isMonitoring: status.isMonitoring,
      isStatusKnown: status.isKnown,
      isHeadphoneConnected: status.isHeadphoneConnected,
      canAlertReliably: status.canAlertReliably,
      // 설정 화면의 항목명과 같은 말을 써야 사용자가 그 자리를 찾는다
      missingReliability: [
        for (final gap in status.missingReliability)
          switch (gap) {
            ReliabilityGap.batteryOptimization =>
              context.l10n.settingsPermBatteryTitle,
            ReliabilityGap.overlay => context.l10n.settingsPermOverlayTitle,
            ReliabilityGap.fullScreenIntent =>
              context.l10n.settingsPermFullScreenTitle,
          },
      ],
      // **push 다 — go 를 쓰면 스택이 교체되어 돌아갈 곳이 사라진다** (이슈 #97).
      // 그러면 AppBar 가 뒤로가기 버튼을 만들지 않고 시스템 뒤로가기도
      // 먹지 않아, 등록을 마치거나 앱을 강제 종료하는 것 외에 나올 길이 없다.
      onAddPlace: () => context.push(AppRoutes.placeNew),
      onEditPlace: (place) => context.push(AppRoutes.placeEdit, extra: place),
      // 감시가 꺼져 있으면 권한 화면이 유일한 해결 경로다
      onFixMonitoring: () => context.go(AppRoutes.onboarding),
      // 신뢰성 권한(#74)을 다시 권한다. 한 번 거절했다는 기록을 지워야
      // 온보딩이 그 단계를 다시 보여준다 — 사용자가 스스로 찾아온 것이므로
      // 기록이 길을 막으면 안 된다.
      onFixReliability: () => _reofferReliability(context, ref),
      onOpenSettings: () => context.push(AppRoutes.settings),
      onRefreshStatus: () => ref.invalidate(homeStatusProvider),
    );
  }
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
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.appUpdateReady),
              duration: const Duration(seconds: 15),
              action: SnackBarAction(
                label: l10n.appUpdateRestart,
                onPressed: () => unawaited(gate.install()),
              ),
            ),
          );
      case AppUpdateOutcome.none:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.appUpdateNone)));
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
      onOpenDiagnostics: () => context.push(AppRoutes.diagnostics),
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
      language: ref.watch(appLanguageControllerProvider),
      onLanguageChanged: (next) async {
        await ref.read(appLanguageControllerProvider.notifier).select(next);
        // 네이티브 알림 문구와 채널 이름도 바뀐 언어로 다시 만든다 (이슈 #164).
        // 알림은 앱이 죽어 있어도 Kotlin 이 만들어서 스스로는 언어 변경을 모른다
        unawaited(ref.read(geofenceRegistrationSyncProvider).refresh());
      },
      permissions: _permissionRows(ref, snapshot, context.l10n),
      // 잠금 화면 알람 (이슈 #235) — iOS 에만 있다. Android 는 전체 화면 알림 권한이 같은 일을 한다
      lockScreenAlarm: Platform.isIOS ? _lockScreenAlarm() : null,
      // 앱 버전과 업데이트 확인 (이슈 #179) — 읽기 실패는 `-` 로 보여준다
      appVersion: ref.watch(appVersionProvider).valueOrNull ?? '-',
      // 앱 내 업데이트가 없는 플랫폼(iOS)은 버튼을 숨긴다 (이슈 #229)
      onCheckUpdate: ref.read(appUpdateGateProvider).isSupported
          ? () => _checkUpdateNow(context)
          : null,
      // 백그라운드 감시 연결 전까지 알림 흐름을 확인하는 수단 (S-4·S-5).
      // 지오펜스 실기기 검증이 끝나면 제거한다.
      onPreviewAlert: () async {
        await ref
            .read(activeAlertProvider.notifier)
            .fire(
              AlertRequest(
                placeId: previewPlaceId,
                placeName: context.l10n.routePreviewPlaceName,
                direction: AlertDirection.enter,
                soundEnabled: true,
                occurredAt: DateTime.now().toUtc(),
                // 지도 카드까지 확인할 수 있어야 미리보기다 (이슈 #142).
                // 좌표가 없으면 카드가 빠진 화면만 보게 된다
                latitude: 37.5665,
                longitude: 126.9780, // 서울시청
                radiusMeters: 200,
              ),
            );
        // 사용자가 해제할 때쯤 광고가 준비되어 있게 미리 불러둔다
        unawaited(_preloadAd(ref));
        if (context.mounted) context.go(AppRoutes.alert);
      },
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

/// 광고 미리 로딩 — 알림 발화 시점에 부른다.
///
/// **반드시 unawaited 로 호출한다.** 로딩을 기다리면 알림 흐름이 막힌다
/// (docs/02-ARCHITECTURE.md 규칙 4).
Future<void> _preloadAd(WidgetRef ref) async {
  try {
    final coordinator = await ref.read(alertAdCoordinatorProvider.future);
    await coordinator.onAlertFired();
  } on Object {
    // 미리 로딩 실패는 무시한다
  }
}
