import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/alert_notifier_impl.dart';
import '../data/alert_sound_service_impl.dart';
import '../data/prefs_alert_volume_store.dart';
import '../data/prefs_vibration_intensity_store.dart';
import '../data/system_volume_channel.dart';
import '../data/vibration_service_impl.dart';
import '../domain/alert_controller.dart';
import '../domain/alert_effects.dart';
import '../domain/alert_session.dart';
import '../domain/audio_route.dart';
import '../domain/vibration_intensity.dart';

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
AlertVolumeStore alertVolumeStore(Ref ref) => PrefsAlertVolumeStore();

@Riverpod(keepAlive: true)
SystemVolumeService systemVolumeService(Ref ref) => const SystemVolumeChannel();

/// 진동 세기 설정 (이슈 #103)
@Riverpod(keepAlive: true)
VibrationIntensityStore vibrationIntensityStore(Ref ref) =>
    PrefsVibrationIntensityStore();

@Riverpod(keepAlive: true)
AlertController alertController(Ref ref) {
  final controller = AlertController(
    vibration: ref.watch(vibrationServiceProvider),
    sound: ref.watch(alertSoundServiceProvider),
    notifier: ref.watch(alertNotifierProvider),
    routeDecider: const AudioRouteDecider(),
    volumeStore: ref.watch(alertVolumeStoreProvider),
    systemVolume: ref.watch(systemVolumeServiceProvider),
    vibrationStore: ref.watch(vibrationIntensityStoreProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// 현재 울리고 있는 알림 세션.
///
/// 화면이 이것을 구독한다 — 세션이 생기면 알림 화면으로,
/// 사라지면 해제 완료 화면으로 전환한다.
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

  Future<void> fire(
    AlertRequest request, {
    Duration vibrationInterval = const Duration(seconds: 3),
  }) async {
    // 세션 갱신은 sessionChanges 스트림이 처리한다
    await ref
        .read(alertControllerProvider)
        .fire(request, vibrationInterval: vibrationInterval);
  }

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
