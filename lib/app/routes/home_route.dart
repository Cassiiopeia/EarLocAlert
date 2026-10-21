part of '../router.dart';

// 지도 홈 라우트

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
    final placeCount = ref.watch(placeListProvider).valueOrNull?.length ?? 0;
    final access = ref.watch(featureAccessControllerProvider);

    return PlaceMapHomeScreen(
      locationService: const CurrentLocationChannel(),
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
            ReliabilityGap.notifications => context.l10n.homeGapNotifications,
            ReliabilityGap.lockScreen => context.l10n.homeGapLockScreen,
            ReliabilityGap.lockScreenAlarm =>
              context.l10n.settingsLockAlarmTitle,
            ReliabilityGap.vibration => context.l10n.homeGapVibration,
          },
      ],
      // 무료 상한·기기 한도를 먼저 본다 (#294). 등록 화면은 push (이슈 #97)
      onAddPlace: () => unawaited(_addPlaceOrOfferPro(context, ref)),
      planBadge: const PlanBadgeChip(),
      isPlaceAddLocked: access.isPlaceAddLocked(placeCount),
      onUnlockPro: () =>
          unawaited(showProOfferSheet(context, entryPoint: 'place_list')),
      onEditPlace: (place) => context.push(AppRoutes.placeEdit, extra: place),
      // 감시가 꺼져 있으면 권한 화면이 유일한 해결 경로다
      onFixMonitoring: () => context.go(AppRoutes.onboarding),
      // 신뢰성 권한(#74)을 다시 권한다. 한 번 거절했다는 기록을 지워야
      // 온보딩이 그 단계를 다시 보여준다 — 사용자가 스스로 찾아온 것이므로
      // 기록이 길을 막으면 안 된다.
      //
      // iOS 는 온보딩에 신뢰성 단계가 없다 (이슈 #237) — 빠진 것에 맞는 곳으로 바로 보낸다
      onFixReliability: Platform.isIOS
          ? () => _fixIosReliability(context, ref, status.missingReliability)
          : () => _reofferReliability(context, ref),
      onOpenSettings: () => context.push(AppRoutes.settings),
      onRefreshStatus: () => ref.invalidate(homeStatusProvider),
    );
  }
}
