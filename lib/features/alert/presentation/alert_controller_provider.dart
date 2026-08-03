import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/alert_notifier_impl.dart';
import '../data/alert_sound_service_impl.dart';
import '../data/vibration_service_impl.dart';
import '../domain/alert_controller.dart';
import '../domain/alert_effects.dart';
import '../domain/alert_session.dart';
import '../domain/audio_route.dart';

part 'alert_controller_provider.g.dart';

@Riverpod(keepAlive: true)
FlutterLocalNotificationsPlugin notificationsPlugin(Ref ref) =>
    FlutterLocalNotificationsPlugin();

@Riverpod(keepAlive: true)
VibrationService vibrationService(Ref ref) => VibrationServiceImpl();

@Riverpod(keepAlive: true)
AlertSoundService alertSoundService(Ref ref) => AlertSoundServiceImpl();

@Riverpod(keepAlive: true)
AlertNotifier alertNotifier(Ref ref) =>
    AlertNotifierImpl(ref.watch(notificationsPluginProvider));

@Riverpod(keepAlive: true)
AlertController alertController(Ref ref) {
  return AlertController(
    vibration: ref.watch(vibrationServiceProvider),
    sound: ref.watch(alertSoundServiceProvider),
    notifier: ref.watch(alertNotifierProvider),
    routeDecider: const AudioRouteDecider(),
  );
}

/// 현재 울리고 있는 알림 세션.
///
/// 화면이 이것을 구독한다 — 세션이 생기면 알림 화면으로,
/// 사라지면 해제 완료 화면으로 전환한다.
@riverpod
class ActiveAlert extends _$ActiveAlert {
  @override
  AlertSession? build() => null;

  Future<void> fire(
    AlertRequest request, {
    Duration vibrationInterval = const Duration(seconds: 3),
  }) async {
    final session = await ref
        .read(alertControllerProvider)
        .fire(request, vibrationInterval: vibrationInterval);
    if (session != null) state = session;
  }

  /// 해제한다.
  ///
  /// **광고를 기다리지 않는다** (docs/02-ARCHITECTURE.md 규칙 4).
  /// 이 메서드가 반환되는 순간 진동과 소리는 이미 멈춰 있다.
  Future<AlertSession?> dismiss() async {
    final controller = ref.read(alertControllerProvider);
    final dismissed = await controller.dismiss();
    // 대기열에 있던 다른 장소 알림이 이어서 울릴 수 있다
    state = controller.current;
    return dismissed;
  }
}
