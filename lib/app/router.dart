import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/places/data/current_location_channel.dart';
import '../features/places/data/place_repository_provider.dart';
import '../features/sounds/data/custom_sound_repository_provider.dart';
import '../core/diagnostics/diagnostics.dart';
import '../core/legal/legal_links.dart';
import '../core/ui/feedback/app_feedback.dart';
import '../core/domain/sound_preset_label.dart';
import '../core/l10n/app_language_controller.dart';
import 'geofence_providers.dart';
import '../core/l10n/l10n.dart';
import '../core/domain/alert_sound.dart';
import '../features/ads/data/ads_providers.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/alert/presentation/alert_screen.dart';
import '../features/alert/presentation/alert_volume_sheet.dart';
import '../features/alert/presentation/vibration_intensity_sheet.dart';
import '../features/permission/domain/ios_notification_settings.dart';
import '../features/permission/data/ios_notification_settings_provider.dart';
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
import '../features/diagnostics/data/bug_report_sender.dart';
import '../features/diagnostics/presentation/bug_report_sheet.dart';
import '../features/places/presentation/place_backup_actions.dart';
import '../features/places/data/place_search_provider.dart';
import 'always_dark_alert_theme.dart';
import '../core/ui/foundation/app_theme_controller.dart';
import '../features/settings/data/prefs_watch_guide_store.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/watch_guide_sheet.dart';
import '../features/sounds/presentation/sound_picker_sheet.dart';
import '../features/app_update/domain/app_updater.dart';
import '../features/app_update/data/app_update_providers.dart';
import 'alert_ad_coordinator_provider.dart';
import 'alert_dismiss_flow.dart';
import 'app_version_provider.dart';
import 'app_state_reporter.dart';
import 'arrival_alarm_providers.dart';
import 'ios_vibration_check/show_ios_vibration_check_sheet.dart';
import 'background/arrival_alarm_channel.dart';
import 'ad_banner_frame.dart';
import 'home_status_provider.dart';
import 'review_prompt_coordinator.dart';
import '../core/entitlement/feature_access.dart';
import '../core/entitlement/feature_access_controller.dart';
import '../core/entitlement/place_limits.dart';
import '../features/places/presentation/place_list_controller.dart';
import '../features/pro/presentation/plan_badge_chip.dart';
import '../features/pro/presentation/pro_offer_sheet.dart';
import '../features/pro/presentation/pro_settings_card.dart';

// 라우트별 조립 코드는 파일을 나눴다 (아키텍처 검수 #276 — 한 파일 736줄)
part 'routes/place_routes.dart';
part 'routes/alert_route.dart';
part 'routes/home_route.dart';
part 'routes/pro_gate.dart';
part 'routes/settings_route.dart';

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
          // 진동 시험 (이슈 #237) — iOS 는 진동 설정을 앱이 읽을 수 없어 처음에 한 번 권한다
          onTestVibration: Platform.isIOS
              ? () => _runVibrationCheck(context, trigger: 'onboarding')
              : null,
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
        builder: (context, state) => const _DiagnosticsRoute(),
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
