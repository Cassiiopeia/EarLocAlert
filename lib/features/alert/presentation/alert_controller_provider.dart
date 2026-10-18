import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/alert_providers.dart';
import '../domain/alert_controller.dart';
import '../domain/alert_session.dart';
import '../domain/audio_route.dart';

part 'alert_controller_provider.g.dart';

/// 현재 울리고 있는 알림 세션.
///
/// 화면이 이것을 구독한다 — 세션이 생기면 알림 화면으로,
/// 사라지면 홈으로 돌아간다 (결정 056).
@riverpod
class ActiveAlert extends _$ActiveAlert {
  @override
  AlertSession? build() {
    final controller = ref.watch(alertControllerProvider);

    // 오디오 경로는 발화 직후 확정되지 않는다 — 재생이 늦게 성공하거나
    // 실패할 수 있으므로 스트림으로 갱신을 받는다.
    final sub = controller.sessionChanges.listen((session) => state = session);
    ref.onDispose(sub.cancel);

    return controller.current;
  }

  /// 마지막 발화에서 소리 재생이 실패했는가 — 화면 문구가 달라진다
  bool get soundFailed => ref.read(alertControllerProvider).lastSoundFailed;

  /// 새 세션을 시작했으면 그 세션을 돌려준다. 이미 울리는 중이라 버렸거나
  /// 줄 세웠으면 null 이다 — 화면 없이 시작하는 경로(이슈 #233)가 이것으로
  /// 반복 알림을 걸지 정한다.
  Future<AlertSession?> fire(
    AlertRequest request, {
    Duration vibrationInterval = const Duration(seconds: 3),
  }) {
    // 세션 갱신은 sessionChanges 스트림이 처리한다
    return ref
        .read(alertControllerProvider)
        .fire(request, vibrationInterval: vibrationInterval);
  }

  /// 지금 세션의 오디오 판정 결과 (이슈 #233) — 실패하지 않는다
  Future<AudioRoute?> audioDecision() =>
      ref.read(alertControllerProvider).audioDecision;

  /// 해제한다.
  ///
  /// **광고를 기다리지 않는다** (docs/02-ARCHITECTURE.md 규칙 4).
  /// 이 메서드가 반환되는 순간 진동과 소리는 이미 멈춰 있다.
  Future<AlertSession?> dismiss() async {
    final controller = ref.read(alertControllerProvider);
    final dismissed = await controller.dismiss();
    // 대기열에 있던 다른 장소 알림이 이어서 울릴 수 있다.
    // 스트림도 갱신하지만 즉시 반영을 위해 여기서도 맞춘다.
    state = controller.current;
    return dismissed;
  }
}
