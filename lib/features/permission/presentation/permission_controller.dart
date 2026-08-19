import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_kind.dart';
import '../domain/permission_service.dart';
import '../domain/permission_snapshot.dart';
import 'reliability_prompt_provider.dart';

part 'permission_controller.g.dart';

/// 권한 상태 컨트롤러 (docs/04-CONVENTIONS.md)
///
/// 화면 데이터는 Provider 에 둔다 — `setState` 로 관리하지 않는다.
@riverpod
class PermissionController extends _$PermissionController {
  @override
  Future<PermissionSnapshot> build() {
    return ref.watch(permissionServiceProvider).check();
  }

  /// 현재 상태를 다시 읽는다.
  ///
  /// 앱이 포그라운드로 돌아올 때 호출한다 — 사용자가 시스템 설정에서
  /// 권한을 바꾸고 왔을 수 있다.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(permissionServiceProvider).check(),
    );
  }

  /// 다음 단계를 실행한다.
  ///
  /// 어떤 권한을 요청할지는 [PermissionGate] 가 정한다 — 화면이 순서를
  /// 알 필요가 없다.
  Future<void> proceed() async {
    final snapshot = state.valueOrNull;
    if (snapshot == null) return;

    final service = ref.read(permissionServiceProvider);
    final gate = ref.read(permissionGateProvider);
    final promptSeen = ref.read(reliabilityPromptProvider).valueOrNull ?? false;

    final step = gate.nextStep(snapshot, reliabilityPromptSeen: promptSeen);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return switch (step) {
        OnboardingStep.requestLocation => service.request(
          PermissionKind.location,
        ),
        OnboardingStep.requestBackgroundLocation => service.request(
          PermissionKind.backgroundLocation,
        ),
        OnboardingStep.requestNotification => service.request(
          PermissionKind.notification,
        ),
        OnboardingStep.requestAlertReliability => _requestReliability(service),
        OnboardingStep.openSettings => service.openAppSettings().then(
          (_) => service.check(),
        ),
        OnboardingStep.done => service.check(),
      };
    });
  }

  /// 신뢰성 권한 3종을 이어서 요청한다 (이슈 #74).
  ///
  /// 전부 시스템 설정 화면으로 나갔다 오는 권한이라 하나씩 순서대로
  /// 처리한다. **이미 허용된 것은 건너뛴다** — 켜져 있는 설정 화면을
  /// 다시 보여주면 사용자는 뭘 하라는 건지 알 수 없다.
  ///
  /// 중간에 하나가 실패해도 나머지를 계속한다. 하나가 막혔다고 나머지
  /// 신뢰성을 포기할 이유가 없다.
  Future<PermissionSnapshot> _requestReliability(
    PermissionService service,
  ) async {
    var snapshot = state.valueOrNull ?? await service.check();

    for (final kind in PermissionGate.reliabilityOrder) {
      if (snapshot.statusOf(kind).isGranted) continue;
      try {
        snapshot = await service.request(kind);
      } on Object {
        // 설정 화면을 못 열었다 — 다음 권한으로 넘어간다
      }
    }

    // 허용됐든 거절됐든 한 번 권한 것으로 친다.
    // 이게 없으면 거절한 사용자가 앱을 켤 때마다 같은 화면을 본다.
    await ref.read(reliabilityPromptProvider.notifier).markSeen();
    return snapshot;
  }

  /// 신뢰성 권한 단계를 건너뛴다 — 다시 묻지 않는다
  Future<void> skipReliabilityPrompt() async {
    await ref.read(reliabilityPromptProvider.notifier).markSeen();
  }

  /// 권한 하나만 요청한다 (이슈 #102).
  ///
  /// [proceed] 와 달리 **순서를 따르지 않는다.** 설정 화면에서 사용자가
  /// 특정 항목을 직접 눌렀을 때 쓴다 — 온보딩처럼 다음 단계를 계산하면
  /// 누른 것과 다른 권한 화면이 열려 사용자가 무엇을 한 건지 알 수 없다.
  Future<void> requestOne(PermissionKind kind) async {
    final service = ref.read(permissionServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => service.request(kind));
  }

  Future<void> openSettings() async {
    await ref.read(permissionServiceProvider).openAppSettings();
  }
}
