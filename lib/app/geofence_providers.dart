import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/providers.dart';
import '../core/domain/id_generator.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/geofence/data/android_geofence_monitor.dart';
import '../features/geofence/data/drift_geofence_event_repository.dart';
import '../features/geofence/domain/geofence_evaluator.dart';
import '../features/geofence/data/native_geofence_monitor.dart';
import '../features/geofence/domain/geofence_monitor.dart';
import '../features/geofence/domain/position_sample.dart';
import '../features/places/data/current_location_channel.dart';
import 'alert_sound_resolver.dart';
import 'background/alert_watch_channel.dart';
import 'background/alert_watch_service.dart';
import 'background/background_alert_notifier.dart';
import 'background/geofence_background_processor.dart';
import 'background/geofence_callback.dart';
import 'background/ios_adaptive_watch.dart';
import 'background/ios_watch_channel.dart';
import 'background/pending_alert.dart';
import 'background/pending_alert_store.dart';
import 'background/region_event_relay.dart';
import 'geofence_registration_sync.dart';
import 'geofence_sync_signal.dart';
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

/// 상시 감시 서비스 (이슈 #74).
///
/// iOS 는 적응형 위치 감시가 이 자리를 맡는다 (이슈 #231) — 등록 동기화가
/// 장소 유무에 따라 켜고 끄는 흐름을 두 플랫폼이 그대로 공유한다.
@Riverpod(keepAlive: true)
AlertWatchService alertWatchService(Ref ref) {
  if (Platform.isIOS) return ref.watch(iosAdaptiveWatchProvider);
  return const AlertWatchChannel();
}

/// iOS 적응형 백그라운드 감시 (이슈 #231)
///
/// 판정기는 **앱의 DB 연결**로 만든다 — 영역 콜백도 이 판정기로 넘어오므로
/// 판정이 한 큐에서 줄을 선다.
@Riverpod(keepAlive: true)
IosAdaptiveWatch iosAdaptiveWatch(Ref ref) {
  final plugin = ref.watch(notificationsPluginProvider);
  final arrivals = StreamController<void>.broadcast();
  ref.onDispose(arrivals.close);
  // 화면 없이 정해진 알림 (이슈 #233) — 앱 루트가 받아 세션을 바로 시작한다
  final backgroundArrivals = StreamController<PendingAlert>.broadcast();
  ref.onDispose(backgroundArrivals.close);

  final alertPort = AppIsolateAlertPort(
    background: BackgroundAlertNotifier(
      plugin: plugin,
      store: PendingAlertStore(),
    ),
    store: PendingAlertStore(),
    // 백그라운드 재실행에서는 부트스트랩이 돌지 않아 플러그인이 초기화되지
    // 않았을 수 있다 — 알림을 내기 직전에 확인한다
    ensureBackgroundReady: () => ensureNotificationsInitialized(plugin),
    isForeground: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    onForegroundAlert: () {
      if (!arrivals.isClosed) arrivals.add(null);
    },
    onBackgroundAlert: (alert) {
      if (!backgroundArrivals.isClosed) backgroundArrivals.add(alert);
    },
  );
  final places = ref.watch(placeRepositoryProvider);
  final watch = IosAdaptiveWatch(
    platform: const IosWatchChannel(),
    processor: GeofenceBackgroundProcessor(
      places: places,
      states: ref.watch(geofenceStateRepositoryProvider),
      events: DriftGeofenceEventRepository(ref.watch(appDatabaseProvider)),
      evaluator: const GeofenceEvaluator(),
      alertPort: alertPort,
      idGenerator: IdGenerator.generate,
      clock: DateTime.now,
    ),
    places: places,
    alertPort: alertPort,
    receiverFactory: RegionEventReceiver.new,
    foregroundAlerts: arrivals.stream,
    backgroundAlerts: backgroundArrivals.stream,
  );
  ref.onDispose(watch.detach);
  return watch;
}

@Riverpod(keepAlive: true)
GeofenceRegistrationSync geofenceRegistrationSync(Ref ref) {
  final sync = GeofenceRegistrationSync(
    places: ref.watch(placeRepositoryProvider),
    monitor: ref.watch(geofenceMonitorProvider),
    states: ref.watch(geofenceStateRepositoryProvider),
    watch: ref.watch(alertWatchServiceProvider),
    onSynced: ref.watch(geofenceSyncSignalProvider).notify,
    // 등록 순간 안팎을 정한다 (이슈 #231) — places 의 위치 조회를 geofence
    // 측정값으로 옮기는 것이 app 계층의 일이다 (규칙 1)
    currentFix: () => currentFixFrom(const CurrentLocationChannel()),
  );
  ref.onDispose(() => sync.stop());
  return sync;
}

/// 등록 동기화가 끝났다는 신호 (이슈 #142 QA) — 홈 상태가 구독한다
@Riverpod(keepAlive: true)
GeofenceSyncSignal geofenceSyncSignal(Ref ref) {
  final signal = GeofenceSyncSignal();
  ref.onDispose(signal.dispose);
  return signal;
}

@Riverpod(keepAlive: true)
PendingAlertLauncher pendingAlertLauncher(Ref ref) => PendingAlertLauncher(
  store: PendingAlertStore(),
  clock: () => DateTime.now().toUtc(),
  // 장소마다 다른 알림음을 재생 가능한 소스로 바꾼다 (이슈 #121)
  soundResolver: AlertSoundResolver(ref.watch(customSoundRepositoryProvider)),
);

/// 현재 위치 1회 조회 결과를 판정용 측정값으로 옮긴다 (이슈 #231).
///
/// 정확도를 모르면 -1(모름)로 둔다 — 0 으로 두면 완벽한 측정으로 오독된다.
/// 실패 사유는 조회 쪽이 이미 남겼다.
Future<PositionSample?> currentFixFrom(CurrentLocationService service) async {
  final result = await service.current();
  final location = result.location;
  if (location == null) return null;
  return PositionSample(
    latitude: location.latitude,
    longitude: location.longitude,
    accuracyMeters: result.accuracyMeters ?? -1,
    timestamp: DateTime.now().toUtc(),
  );
}
