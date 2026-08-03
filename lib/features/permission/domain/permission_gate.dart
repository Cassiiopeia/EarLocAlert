import 'permission_kind.dart';
import 'permission_snapshot.dart';

/// 온보딩에서 다음에 할 일
enum OnboardingStep {
  /// 사용 중 위치 요청
  requestLocation,

  /// 항상 위치 요청 (Android 는 설정 화면 이동)
  requestBackgroundLocation,

  /// 알림 권한 요청
  requestNotification,

  /// 설정 화면으로 보내야 함 — 영구 거부된 권한이 있다
  openSettings,

  /// 더 요청할 것이 없다
  done,
}

/// 온보딩 진행 판정 (docs/05-PLATFORM.md 권한 요청 순서)
///
/// **순수 로직이다.** `permission_handler` 도 플랫폼도 모른다 —
/// 실기기 없이 조합별 동작을 테스트하기 위해서다
/// (docs/02-ARCHITECTURE.md).
class PermissionGate {
  const PermissionGate();

  /// 요청 순서는 고정이다.
  ///
  /// 사용 중 위치를 먼저 받지 않으면 항상 위치 요청이 의미가 없고,
  /// 알림은 마지막에 둔다 — 앞의 두 개가 이 앱의 본질이라
  /// 권한 피로가 쌓이기 전에 받아야 한다.
  static const List<PermissionKind> requestOrder = [
    PermissionKind.location,
    PermissionKind.backgroundLocation,
    PermissionKind.notification,
  ];

  /// 현재 상태에서 다음에 해야 할 일.
  ///
  /// 영구 거부는 앱 내 재요청이 통하지 않으므로 설정 화면으로 보낸다.
  /// 다만 **아직 요청 가능한 권한이 남아 있으면 그것을 먼저** 처리한다 —
  /// 하나가 영구 거부됐다고 나머지 흐름을 막지 않는다.
  OnboardingStep nextStep(PermissionSnapshot snapshot) {
    for (final kind in requestOrder) {
      final status = snapshot.statusOf(kind);
      if (status.isGranted) continue;
      if (status.canRequestAgain) return _stepFor(kind);
    }

    // 남은 것이 전부 영구 거부·제한 상태인지 확인
    final blocked = requestOrder
        .map(snapshot.statusOf)
        .any((s) => s.needsSettings);
    if (blocked) return OnboardingStep.openSettings;

    return OnboardingStep.done;
  }

  /// 아직 허용되지 않은 권한들
  List<PermissionKind> missing(PermissionSnapshot snapshot) {
    return requestOrder
        .where((kind) => !snapshot.statusOf(kind).isGranted)
        .toList();
  }

  /// 온보딩을 마쳐도 되는가.
  ///
  /// 모든 권한이 허용된 경우뿐 아니라, **더 이상 앱이 할 수 있는 것이
  /// 없을 때도 true 다** — 영구 거부 상태에서 온보딩에 사용자를 가둬두지
  /// 않는다. 앱은 열리고, 무엇이 안 되는지를 화면에 표시한다 (A-12).
  bool canLeaveOnboarding(PermissionSnapshot snapshot) {
    final step = nextStep(snapshot);
    return step == OnboardingStep.done || step == OnboardingStep.openSettings;
  }

  OnboardingStep _stepFor(PermissionKind kind) => switch (kind) {
    PermissionKind.location => OnboardingStep.requestLocation,
    PermissionKind.backgroundLocation =>
      OnboardingStep.requestBackgroundLocation,
    PermissionKind.notification => OnboardingStep.requestNotification,
  };
}
