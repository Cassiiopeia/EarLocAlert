part of '../router.dart';

// 무료/프로 경계에서 막을지 안내할지 정하는 진입점 배선 (#294, #366)

/// 홈 잠금 안내 문구를 "벌써 N번 울렸어요"로 바꾸는 알림 해제 누적 횟수
const int _proNudgeMinimumDismissCount = 3;

/// 홈 잠금 안내에 넣을 횟수: 기준 이상 > 그 횟수, 미만 > null (기본 문구)
int? _proNudgeDismissCount(WidgetRef ref) {
  final count = ref.watch(alertDismissCountProvider).valueOrNull ?? 0;
  return count >= _proNudgeMinimumDismissCount ? count : null;
}

/// 장소 추가: 무료 상한 > 프로 안내(결제하면 등록 화면으로 이어감), 기기 한도 > 안내 문구, 그 외 > 등록 화면
Future<void> _addPlaceOrOfferPro(
  BuildContext context,
  WidgetRef ref, {
  ProOfferEntry entry = ProOfferEntry.placeAdd,
}) async {
  final placeCount = await ref.read(placeRepositoryProvider).count();
  if (!context.mounted) return;
  final access = ref.read(featureAccessControllerProvider);
  if (access.isPlaceAddLocked(placeCount)) {
    final isUnlocked = await showProOfferSheet(context, entry: entry);
    if (!isUnlocked || !context.mounted) return;
    Diagnostics.log('pro', 'place add continued after unlock');
  } else if (access.isAtDeviceLimit(placeCount)) {
    Diagnostics.log(
      'pro',
      'place add blocked reason=device_limit count=$placeCount',
    );
    context.showToast(
      context.l10n.proDeviceLimitReached(PlaceLimits.platformMaximum()),
    );
    return;
  }
  // **push 다 — go 를 쓰면 스택이 교체되어 돌아갈 곳이 사라진다** (이슈 #97)
  await context.push(AppRoutes.placeNew);
}

/// 저장 시 상한 거절: 무료 > 프로 안내(결제하면 true > 폼이 저장 재시도), 그 외 > 기기 한도 문구
Future<bool> _offerProOnPlaceLimit(BuildContext context, WidgetRef ref) async {
  final access = ref.read(featureAccessControllerProvider);
  if (access.isPaywallEnabled && !access.isPro) {
    return showProOfferSheet(context, entry: ProOfferEntry.placeSave);
  }
  context.showToast(
    context.l10n.proDeviceLimitReached(PlaceLimits.platformMaximum()),
  );
  return false;
}
