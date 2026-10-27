import 'place_limits.dart';
import 'pro_entitlement.dart';

/// 지금 쓸 수 있는 기능: 장소 상한, 알림음 전체, 진동 패턴 전체, 도착 기록 전체, 장소 백업, 광고 (#294 #311 #313)
/// 결제 화면이 꺼진 플랫폼(Android·iOS 외)은 등급 없이 전부 열고 광고만 유지
class FeatureAccess {
  const FeatureAccess({required this.isPaywallEnabled, required this.source});

  /// 무료/프로 구분과 결제 UI 를 쓰는 플랫폼인가 (Android #294 · iOS #298)
  final bool isPaywallEnabled;
  final ProEntitlementSource source;

  bool get isPro => isPaywallEnabled && source.isPro;

  bool get _isUnlocked => !isPaywallEnabled || source.isPro;

  int get placeLimit =>
      _isUnlocked ? PlaceLimits.platformMaximum() : PlaceLimits.freePlaces;

  bool get canUseAllSounds => _isUnlocked;

  /// 기본 진동 외 패턴을 고를 수 있는가 (#311). 이미 지정한 패턴의 재생은 등급과 무관
  bool get canUseAllVibrationPatterns => _isUnlocked;

  bool get canUsePlaceBackup => _isUnlocked;

  /// 도착 기록 전체·요약을 볼 수 있는가 (#313). 무료는 최근 몇 건만
  bool get canViewFullHistory => _isUnlocked;

  bool get shouldShowAds => !isPro;

  /// 무료 상한에 걸려 장소 추가를 막아야 하는가 (결제 안내 대상)
  bool isPlaceAddLocked(int placeCount) =>
      !_isUnlocked && placeCount >= PlaceLimits.freePlaces;

  /// 등급과 무관한 기기 한도에 닿았는가 (안내만)
  bool isAtDeviceLimit(int placeCount) =>
      !isPlaceAddLocked(placeCount) &&
      placeCount >= PlaceLimits.platformMaximum();
}
