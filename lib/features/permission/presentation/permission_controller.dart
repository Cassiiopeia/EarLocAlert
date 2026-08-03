import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_kind.dart';
import '../domain/permission_snapshot.dart';

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

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return switch (gate.nextStep(snapshot)) {
        OnboardingStep.requestLocation => service.request(
          PermissionKind.location,
        ),
        OnboardingStep.requestBackgroundLocation => service.request(
          PermissionKind.backgroundLocation,
        ),
        OnboardingStep.requestNotification => service.request(
          PermissionKind.notification,
        ),
        OnboardingStep.openSettings => service.openAppSettings().then(
          (_) => service.check(),
        ),
        OnboardingStep.done => service.check(),
      };
    });
  }

  Future<void> openSettings() async {
    await ref.read(permissionServiceProvider).openAppSettings();
  }
}
