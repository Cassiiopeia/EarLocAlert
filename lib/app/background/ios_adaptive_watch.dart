import 'dart:async';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/diagnostics/log_format.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/geofence/domain/geofence_target.dart';
import '../../features/geofence/domain/position_sample.dart';
import '../../features/geofence/domain/watch_tier.dart';
import '../../features/places/domain/place_repository.dart';
import 'alert_watch_service.dart';
import 'background_alert_port.dart';
import 'geofence_background_processor.dart';
import 'ios_watch_channel.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';
import 'region_event_relay.dart';
import 'serial_task_queue.dart';

/// iOS 적응형 백그라운드 감시의 Dart 쪽 (이슈 #231)
///
/// Android 의 감시 서비스(결정 024)에 해당한다. [AlertWatchService] 를 구현해
/// 등록 동기화가 장소 유무에 따라 켜고 끄는 흐름을 그대로 탄다.
///
/// **앱 isolate 에서 돈다.** iOS 는 백그라운드 위치 갱신을 받는 동안 앱을 살려
/// 두므로 화면이 없어도 이 isolate 는 측정을 받는다. 판정은 앱의 DB 연결로 한다 —
/// 두 번째 연결을 동시에 열지 않는다.
///
/// 하는 일:
/// 1. 측정마다 가장 가까운 근접 원까지 거리로 단계를 고르고([WatchTierPolicy]),
///    바뀌면 네이티브에 알린다
/// 2. 근접 원 안의 측정은 정밀 판정([GeofenceBackgroundProcessor.handlePosition])에
///    넣는다 — Android 감시 엔진과 같은 판정기다
/// 3. 영역 콜백이 넘긴 이벤트도 **같은 판정기**로 판정한다 — 두 경로가 한 큐를
///    타므로 같은 도착이 두 번 울리지 않는다 (`inside → inside` 는 무알림)
class IosAdaptiveWatch implements AlertWatchService {
  IosAdaptiveWatch({
    required IosWatchPlatform platform,
    required GeofenceBackgroundProcessor processor,
    required PlaceRepository places,
    required BackgroundAlertPort alertPort,
    RegionEventReceiver Function(
      Future<void> Function(RegionEvent event) handle,
    )?
    receiverFactory,
    WatchTierPolicy? policy,
    DateTime Function()? clock,
    this.heartbeatInterval = const Duration(minutes: 10),
    this.foregroundAlerts = const Stream.empty(),
  }) : _platform = platform,
       _processor = processor,
       _places = places,
       _alertPort = alertPort,
       _receiverFactory = receiverFactory,
       _policy = policy ?? WatchTierPolicy(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final IosWatchPlatform _platform;
  final GeofenceBackgroundProcessor _processor;
  final PlaceRepository _places;
  final BackgroundAlertPort _alertPort;
  final RegionEventReceiver Function(
    Future<void> Function(RegionEvent event) handle,
  )?
  _receiverFactory;
  final WatchTierPolicy _policy;
  final DateTime Function() _clock;

  /// 근접 원 밖 측정은 이 간격으로만 남긴다 — 감시가 살아 있다는 증거로는
  /// 충분하고, 매 측정을 남기면 로그가 그것만으로 찬다 (이슈 #127)
  final Duration heartbeatInterval;

  /// 화면이 떠 있는 동안 알림이 결정됐다는 신호 — 앱 루트가 받아 곧장
  /// 알림 화면으로 승격한다 (3초 폴링을 기다리지 않는다)
  final Stream<void> foregroundAlerts;

  /// 측정을 하나씩 처리한다 — 단계 전환 순서가 측정 순서와 같아야 한다
  final _queue = SerialTaskQueue();
  DateTime? _lastHeartbeat;
  bool _attached = false;
  RegionEventReceiver? _receiver;

  WatchTier get tier => _policy.tier;

  /// 측정 처리기와 영역 이벤트 수신기를 단다. 앱이 뜨자마자 한 번 부른다 —
  /// 백그라운드 재실행에서는 첫 프레임이 오지 않아 부트스트랩을 기다릴 수 없다.
  Future<void> attach() async {
    if (_attached) return;
    _attached = true;
    _receiver = _receiverFactory?.call(handleRegionEvent)?..attach();
    await _platform.attach(onFix);
  }

  /// 영역 이벤트 수신을 내린다 — 이름이 남으면 콜백이 죽은 포트로 보내 시간 초과를 기다린다
  void detach() {
    _receiver?.detach();
    _receiver = null;
  }

  @override
  Future<void> startWatching() async {
    final result = await _platform.start(_policy.tier);
    if (result.started) {
      Diagnostics.log('watch', 'ios watch start requested tier=${tier.name}');
    } else {
      // "항상" 권한이 없으면 영역 감시만 남는다 — 왜 위치 표시가 없는지의 답이다
      Diagnostics.log(
        'watch',
        'ios watch not started reason=${result.reason} '
            '(region monitoring only)',
      );
    }
  }

  @override
  Future<void> stopWatching() async {
    await _platform.stop();
    Diagnostics.log('watch', 'ios watch stopped reason=no_places');
  }

  // 아래는 Android 감시 서비스 전용 — iOS 는 반복 진동·화면 승격이 없다
  @override
  Future<void> stopNativeAlert() async {}

  @override
  Future<bool> isAlerting() async => false;

  @override
  Future<void> syncGeofences(List<Map<String, Object?>> geofences) async {}

  /// 네이티브 측정 하나 (이슈 #231)
  Future<void> onFix(PositionSample sample) => _queue.run(() => _onFix(sample));

  Future<void> _onFix(PositionSample sample) async {
    final targets = [
      for (final place in await _places.findAll())
        if (place.enabled)
          GeofenceTarget(
            placeId: place.id,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: place.radiusMeters,
            direction: place.direction,
          ),
    ];
    final gap = nearestRingGapMeters(sample, targets);

    final before = _policy.tier;
    final next = _policy.next(
      gapMeters: gap,
      accuracyMeters: sample.accuracyMeters,
      at: sample.timestamp,
    );
    if (next != before) {
      Diagnostics.log(
        'watch',
        'tier changed tier=${next.name} from=${before.name} '
            'nearest=${meters(gap)} acc=${meters(sample.accuracyMeters)}'
            '${_policy.preciseCapped ? " reason=precise_cap" : ""}',
      );
      await _platform.setTier(next);
    }

    // 근접 원 안의 측정만 판정한다 — 밖이면 어느 장소에도 들어갈 수 없다.
    // 단계와 무관하게 본다: 상한에 걸린 중간 단계 측정도 판정 대상이다
    if (gap != null && gap <= 0) {
      final alert = await _processor.handlePosition(sample: sample);
      if (alert != null) await _deliver(alert, source: 'precise');
      return;
    }

    final now = _clock();
    final last = _lastHeartbeat;
    if (last == null || now.difference(last) >= heartbeatInterval) {
      _lastHeartbeat = now;
      Diagnostics.log(
        'watch',
        'ios fix lat=${sample.latitude} lng=${sample.longitude} '
            'acc=${meters(sample.accuracyMeters)} tier=${next.name} '
            'nearest=${meters(gap)}',
      );
    }
  }

  /// 영역 콜백이 넘긴 이벤트 (이슈 #231) — 정밀 판정과 같은 판정기로 본다
  Future<void> handleRegionEvent(RegionEvent event) async {
    Diagnostics.log(
      'geofence',
      'region event received in app place=${shortId(event.placeId)} '
          'event=${event.direction}',
    );
    final alert = await _processor.handleTransition(
      placeId: event.placeId,
      eventType: event.entered
          ? GeofenceEventType.entered
          : GeofenceEventType.exited,
      latitude: event.latitude,
      longitude: event.longitude,
    );
    if (alert != null) await _deliver(alert, source: 'region');
  }

  Future<void> _deliver(PendingAlert alert, {required String source}) async {
    Diagnostics.log(
      'watch',
      'alert decided place=${alert.placeName} direction=${alert.direction.name} '
          'source=$source',
    );
    await _alertPort.notify(alert);
  }
}

/// 앱 isolate 의 알림 출구 (이슈 #231)
///
/// **화면이 떠 있으면 OS 알림을 띄우지 않고 곧장 앱 세션으로 잇는다.** 배너가
/// 떴다가 바로 지워지는 것보다, 알림 화면이 바로 뜨는 쪽이 맞다. 대기 알림
/// 저장은 같다 — 승격은 기존 경로(`PendingAlertResumer`)가 한다.
///
/// 화면이 없으면 영역 콜백과 같은 백그라운드 알림(무음 햅틱, 결정 053)을 낸다.
class AppIsolateAlertPort implements BackgroundAlertPort {
  AppIsolateAlertPort({
    required BackgroundAlertPort background,
    required PendingAlertStore store,
    required bool Function() isForeground,
    required void Function() onForegroundAlert,
    Future<void> Function()? ensureBackgroundReady,
  }) : _background = background,
       _store = store,
       _isForeground = isForeground,
       _onForegroundAlert = onForegroundAlert,
       _ensureBackgroundReady = ensureBackgroundReady;

  final BackgroundAlertPort _background;
  final Future<void> Function()? _ensureBackgroundReady;
  final PendingAlertStore _store;
  final bool Function() _isForeground;
  final void Function() _onForegroundAlert;

  @override
  Future<void> notify(PendingAlert alert) async {
    if (_isForeground()) {
      await _store.save(alert);
      Diagnostics.log(
        'watch',
        'alert handed to app place=${alert.placeName} via=foreground',
      );
      _onForegroundAlert();
      return;
    }
    try {
      await _ensureBackgroundReady?.call();
    } on Object catch (error) {
      // 초기화가 실패해도 발행은 시도한다 — 대기 알림 저장은 그 안에서 먼저 된다
      Diagnostics.log('notify', 'notification init before post failed $error');
    }
    await _background.notify(alert);
  }
}
