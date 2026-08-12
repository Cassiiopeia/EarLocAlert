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

  /// 알림 신뢰성 권한 요청 — 배터리 최적화 예외·오버레이·전체화면 (이슈 #74)
  ///
  /// **선택 단계다.** 건너뛰어도 온보딩을 마칠 수 있고, 한 번 거절하면
  /// 다시 묻지 않는다.
  requestAlertReliability,

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

  /// 알림 신뢰성 권한 요청 순서 (이슈 #74)
  ///
  /// 전부 시스템 설정 화면으로 나갔다 오는 권한이라 한 단계에서 이어서
  /// 처리한다. 순서는 효과가 큰 것부터다 — 배터리 최적화 예외가 없으면
  /// 이벤트 자체가 늦게 오고, 그다음이 화면을 덮는 능력이다.
  static const List<PermissionKind> reliabilityOrder = [
    PermissionKind.batteryOptimization,
    PermissionKind.overlay,
    PermissionKind.fullScreenIntent,
  ];

  /// 현재 상태에서 다음에 해야 할 일.
  ///
  /// 영구 거부는 앱 내 재요청이 통하지 않으므로 설정 화면으로 보낸다.
  /// 다만 **아직 요청 가능한 권한이 남아 있으면 그것을 먼저** 처리한다 —
  /// 하나가 영구 거부됐다고 나머지 흐름을 막지 않는다.
  ///
  /// [reliabilityPromptSeen] 은 신뢰성 권한을 이미 한 번 권했는지다.
  /// 거절한 사용자에게 앱을 켤 때마다 같은 화면을 보이면 통행세가 된다.
  OnboardingStep nextStep(
    PermissionSnapshot snapshot, {
    bool reliabilityPromptSeen = false,
  }) {
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

    // 필수가 끝났다 — 알림이 백그라운드에서 끊기지 않도록 한 번 더 권한다.
    // 필수가 막혀 있는 동안에는 오지 않는다: 항상 위치 없이 오버레이만
    // 받아봐야 알릴 것이 없다.
    if (!reliabilityPromptSeen && !snapshot.canAlertReliably) {
      return OnboardingStep.requestAlertReliability;
    }

    return OnboardingStep.done;
  }

  /// 아직 허용되지 않은 권한들
  List<PermissionKind> missing(PermissionSnapshot snapshot) {
    return requestOrder
        .where((kind) => !snapshot.statusOf(kind).isGranted)
        .toList();
  }

  // 온보딩을 나갈 수 있는지는 **판정하지 않는다** (이슈 #90).
  //
  // 언제나 나갈 수 있기 때문이다. 이전에는 "영구 거부라 더 할 게 없을 때만"
  // 내보냈는데, 그러면 한 번 거부(재요청 가능)한 사용자가 갇힌다. iOS 는
  // 한 번 거부하면 다이얼로그를 다시 띄우지 않으므로 버튼이 아무 일도
  // 하지 않는 화면이 된다 — 권한 없이도 기본 화면에는 닿아야 한다는
  // App Store 심사 방침에도 어긋난다 (A-12).
  //
  // 대신 화면이 완료 단계가 아닌 모든 단계에 "나중에 하기"를 둔다.
  // 무엇이 안 되는지는 홈에서 상시 표시한다.

  OnboardingStep _stepFor(PermissionKind kind) => switch (kind) {
    PermissionKind.location => OnboardingStep.requestLocation,
    PermissionKind.backgroundLocation =>
      OnboardingStep.requestBackgroundLocation,
    PermissionKind.notification => OnboardingStep.requestNotification,
    PermissionKind.batteryOptimization ||
    PermissionKind.overlay ||
    PermissionKind.fullScreenIntent => OnboardingStep.requestAlertReliability,
  };
}
