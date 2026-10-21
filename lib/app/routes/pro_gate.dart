part of '../router.dart';

// 무료/프로 경계에서 막을지 안내할지 정하는 진입점 배선 (#294)

/// 장소 추가: 무료 상한 > 프로 안내, 기기 한도 > 안내 문구, 그 외 > 등록 화면
Future<void> _addPlaceOrOfferPro(BuildContext context, WidgetRef ref) async {
  final placeCount = await ref.read(placeRepositoryProvider).count();
  if (!context.mounted) return;
  final access = ref.read(featureAccessControllerProvider);
  if (access.isPlaceAddLocked(placeCount)) {
    await showProOfferSheet(context, entryPoint: 'place_add');
    return;
  }
  if (access.isAtDeviceLimit(placeCount)) {
    Diagnostics.log(
      'pro',
      'place add blocked reason=device_limit count=$placeCount',
    );
    context.showToast(_deviceLimitMessage(context, access));
    return;
  }
  // **push 다 — go 를 쓰면 스택이 교체되어 돌아갈 곳이 사라진다** (이슈 #97)
  await context.push(AppRoutes.placeNew);
}

/// 저장 시 상한 거절: 무료 > 프로 안내, 그 외 > 기기 한도 문구
void _onPlaceLimitReached(BuildContext context, WidgetRef ref) {
  final access = ref.read(featureAccessControllerProvider);
  if (access.isPaywallEnabled && !access.isPro) {
    unawaited(showProOfferSheet(context, entryPoint: 'place_save'));
    return;
  }
  context.showToast(_deviceLimitMessage(context, access));
}

/// 기기 한도 문구: Android 프로 > "기기 한도에 도달했어요", iOS > 기존 "최대 20개" 문구 그대로
String _deviceLimitMessage(BuildContext context, FeatureAccess access) =>
    access.isPaywallEnabled
    ? context.l10n.proDeviceLimitReached
    : context.l10n.placeErrorLimit(PlaceLimits.platformMaximum());
