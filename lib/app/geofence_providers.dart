import 'dart:io' show Platform;

// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/providers.dart';
import '../features/geofence/data/android_geofence_monitor.dart';
import '../features/geofence/data/native_geofence_monitor.dart';
import '../features/geofence/domain/geofence_monitor.dart';
import 'background/alert_watch_channel.dart';
import 'background/alert_watch_service.dart';
import 'background/geofence_callback.dart';
import 'background/pending_alert_store.dart';
import 'geofence_registration_sync.dart';
import 'pending_alert_launcher.dart';

part 'geofence_providers.g.dart';

/// 백그라운드 감시 조립 (이슈 #63, docs/02-ARCHITECTURE.md)
///
/// geofence·places 를 잇는 조율 객체들은 app 계층 소속이라
/// core/di 가 아닌 여기에 둔다.

/// 플랫폼마다 감시 방식이 다르다 (이슈 #93, 결정 017 재검토)
///
/// Android 는 native_geofence 의 WorkManager 경유가 이벤트를 지연·유실시켜
/// 자체 구현으로 대체했다. iOS 는 그 경로가 없어 그대로 쓴다.
@Riverpod(keepAlive: true)
GeofenceMonitor geofenceMonitor(Ref ref) {
  if (Platform.isAndroid) return const AndroidGeofenceMonitor();
  return NativeGeofenceMonitor(callback: geofenceBackgroundCallback);
}

/// 상시 감시 서비스 (이슈 #74). iOS 에는 채널이 없어 조용히 무시된다.
@Riverpod(keepAlive: true)
AlertWatchService alertWatchService(Ref ref) => const AlertWatchChannel();

@Riverpod(keepAlive: true)
GeofenceRegistrationSync geofenceRegistrationSync(Ref ref) {
  final sync = GeofenceRegistrationSync(
    places: ref.watch(placeRepositoryProvider),
    monitor: ref.watch(geofenceMonitorProvider),
    states: ref.watch(geofenceStateRepositoryProvider),
    watch: ref.watch(alertWatchServiceProvider),
  );
  ref.onDispose(() => sync.stop());
  return sync;
}

@Riverpod(keepAlive: true)
PendingAlertLauncher pendingAlertLauncher(Ref ref) => PendingAlertLauncher(
  store: PendingAlertStore(),
  clock: () => DateTime.now().toUtc(),
);
