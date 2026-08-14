import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/alert_direction.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/domain/alert_controller.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/alert/presentation/alert_dismissed_screen.dart';
import '../features/alert/presentation/alert_screen.dart';
import '../features/alert/presentation/alert_volume_sheet.dart';
import '../features/permission/presentation/onboarding_screen.dart';
import '../features/permission/presentation/reliability_prompt_provider.dart';
import '../features/places/domain/alert_place.dart';
import '../features/places/presentation/place_form_screen.dart';
import '../features/places/presentation/place_map_home_screen.dart';
import '../features/places/presentation/place_map_picker_screen.dart';
import '../features/diagnostics/presentation/diagnostics_screen.dart';
import '../features/places/presentation/place_search_provider.dart';
import 'home_status_provider.dart';

/// 앱 라우팅 (docs/02-ARCHITECTURE.md)
///
/// `Navigator.push` 를 직접 호출하지 않는다 — 모든 화면 전환은
/// go_router 를 거친다.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const alert = '/alert';
  static const alertDismissed = '/alert/dismissed';
  static const placeNew = '/places/new';
  static const placeEdit = '/places/edit';
  static const placeMap = '/places/map';

  /// 진단 기록 (이슈 #95) — 백그라운드 문제를 확인하는 유일한 창구
  static const diagnostics = '/diagnostics';
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
        builder: (context, state) => const _HomeRoute(),
      ),
      GoRoute(
        path: AppRoutes.placeNew,
        builder: (context, state) => PlaceFormScreen(
          onSaved: () => _leaveForm(context),
          onPickOnMap: (args) => _pickOnMap(context, args),
        ),
      ),
      GoRoute(
        path: AppRoutes.placeEdit,
        builder: (context, state) => PlaceFormScreen(
          existing: state.extra as AlertPlace?,
          onSaved: () => _leaveForm(context),
          onPickOnMap: (args) => _pickOnMap(context, args),
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
        path: AppRoutes.alert,
        builder: (context, state) => const _AlertRoute(),
      ),
      GoRoute(
        path: AppRoutes.alertDismissed,
        builder: (context, state) => AlertDismissedScreen(
          placeName: state.extra as String? ?? '',
          onContinue: () => context.go(AppRoutes.home),
        ),
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
      // 선택 결과를 push 를 기다리던 폼에게 돌려준다
      onPicked: (result) => context.pop(result),
    );
  }
}

/// 지도 화면을 열고 선택 결과를 기다린다.
///
/// 폼은 `Navigator`·`GoRouter` 를 직접 만지지 않는다 — 화면 전환은 전부
/// 여기서 조율한다 (docs/02-ARCHITECTURE.md).
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

/// 알림 화면 라우트.
///
/// 해제 시 **광고를 기다리지 않고** 곧바로 화면을 전환한다
/// (docs/02-ARCHITECTURE.md 규칙 4).
class _AlertRoute extends ConsumerWidget {
  const _AlertRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeAlertProvider);

    if (session == null) {
      // 세션이 없는 상태로 들어왔다 — 홈으로 돌린다
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return AlertScreen(
      session: session,
      soundFailed: ref.read(activeAlertProvider.notifier).soundFailed,
      onDismiss: () async {
        final placeName = session.placeName;

        // 1) 해제가 먼저다. 광고와 무관하게 여기서 진동·소리가 멈춘다
        final dismissed = await ref
            .read(activeAlertProvider.notifier)
            .dismiss();
        if (!context.mounted) return;

        // 대기 중이던 다른 장소 알림이 이어서 울리면 이 화면에 머문다
        if (ref.read(activeAlertProvider) != null) return;

        if (dismissed == null) {
          context.go(AppRoutes.home);
          return;
        }

        // 2) 그 다음에 광고를 시도한다 (docs/02-ARCHITECTURE.md 규칙 4).
        //    실패·지연은 조율자가 삼키므로 여기서 처리할 것이 없다.
        context.go(AppRoutes.alertDismissed, extra: placeName);
        unawaited(_tryShowAd(ref));
      },
    );
  }

  Future<void> _tryShowAd(WidgetRef ref) async {
    try {
      final coordinator = await ref.read(alertAdCoordinatorProvider.future);
      await coordinator.onAlertDismissed(now: DateTime.now().toUtc());
    } on Object {
      // 광고는 부가 기능이다 — 실패해도 사용자 흐름에 영향이 없다
    }
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
      isHeadphoneConnected: status.isHeadphoneConnected,
      canAlertReliably: status.canAlertReliably,
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
      onOpenDiagnostics: () => context.push(AppRoutes.diagnostics),
      onRefreshStatus: () => ref.invalidate(homeStatusProvider),
      // 백그라운드 감시 연결 전까지 알림 흐름을 확인하는 수단 (S-4·S-5).
      // 지오펜스 연동이 끝나면 제거한다.
      onPreviewAlert: () async {
        await ref
            .read(activeAlertProvider.notifier)
            .fire(
              AlertRequest(
                placeId: 'preview',
                placeName: '테스트 장소',
                direction: AlertDirection.enter,
                soundEnabled: true,
                occurredAt: DateTime.now().toUtc(),
              ),
            );
        // 사용자가 해제할 때쯤 광고가 준비되어 있게 미리 불러둔다
        unawaited(_preloadAd(ref));
        if (context.mounted) context.go(AppRoutes.alert);
      },
      // 알림음 크기 설정 (이슈 #86) — alert feature 의 시트를 app 이 잇는다
      onOpenVolumeSettings: () => showAlertVolumeSheet(context),
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
