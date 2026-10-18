import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import './alert_notifier_impl.dart';
import './alert_sound_service_impl.dart';
import './prefs_alert_volume_store.dart';
import './prefs_vibration_intensity_store.dart';
import './system_volume_channel.dart';
import './ios_system_vibration.dart';
import './vibration_service_impl.dart';
import '../domain/alert_controller.dart';
import '../domain/alert_effects.dart';
import '../domain/audio_route.dart';
import '../domain/vibration_intensity.dart';

part 'alert_providers.g.dart';

@Riverpod(keepAlive: true)
FlutterLocalNotificationsPlugin notificationsPlugin(Ref ref) =>
    FlutterLocalNotificationsPlugin();

/// iOS 는 화면 없이 세션이 돌 수 있다 (이슈 #233). 그동안 Core Haptics 가
/// 재생되지 않아 시스템 진동으로 바꿔 떤다 (이슈 #235)
@Riverpod(keepAlive: true)
VibrationService vibrationService(Ref ref) => VibrationServiceImpl(
  system: Platform.isIOS
      ? IosSystemVibration(
          isBackground: () =>
              WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed,
        )
      : null,
);

/// iOS 는 앱이 화면 없이 세션을 시작할 수 있다 (이슈 #233) — 그때는 오디오
/// 세션 설정이 달라야 활성화된다. Android 는 늘 전면에서 시작하므로 바꾸지 않는다.
@Riverpod(keepAlive: true)
AlertSoundService alertSoundService(Ref ref) => AlertSoundServiceImpl(
  startsInBackground: () =>
      Platform.isIOS &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed,
);

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
    // 화면 없이 도는 iOS 세션만 — Android 는 진동이 오디오와 무관하다 (이슈 #241)
    needsSilentKeepAlive: () =>
        Platform.isIOS &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed,
  );
  ref.onDispose(controller.dispose);
  return controller;
}
