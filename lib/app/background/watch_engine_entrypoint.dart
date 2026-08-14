import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/id_generator.dart';
import '../../features/geofence/data/drift_geofence_event_repository.dart';
import '../../features/geofence/data/drift_geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/places/data/drift_place_repository.dart';
import 'background_alert_notifier.dart';
import 'geofence_background_processor.dart';
import 'pending_alert_store.dart';
import 'watch_engine_host.dart';

/// 감시 서비스가 보유하는 엔진의 진입점 (이슈 #93)
///
/// `AlertWatchService` 가 이 함수로 엔진을 띄우고, 이후 이벤트마다 채널로
/// 판정을 요청한다. **이벤트마다 엔진을 새로 띄우지 않는 것이 이 이슈의
/// 핵심 수정이다** — 엔진 부팅에는 실패 지점이 셋 있고, 그 실패가 반복되면
/// 알림이 통째로 사라진다.
///
/// **UI 가 없다** — BuildContext·위젯 트리 Provider 접근 금지
/// (docs/02-ARCHITECTURE.md 규칙 5).
///
/// 어떤 예외도 밖으로 던지지 않는다. 여기서 죽으면 감시가 조용히 사라진다.
@pragma('vm:entry-point')
void watchEngineMain() {
  WidgetsFlutterBinding.ensureInitialized();

  // 엔진 수명 동안 하나만 연다. 짧은 콜백과 달리 여기서는 연결을 유지해도
  // 되지만, 판정은 장소 목록을 그때그때 읽어 최신 상태를 본다.
  final db = AppDatabase();

  final host = WatchEngineHost(
    processor: GeofenceBackgroundProcessor(
      places: DriftPlaceRepository(db),
      states: DriftGeofenceStateRepository(db),
      events: DriftGeofenceEventRepository(db),
      evaluator: const GeofenceEvaluator(),
      // 이 경로에서는 알림을 발행하지 않는다 — 발화 주체가 네이티브
      // 서비스다. 포트는 handle() 을 쓰는 iOS 경로와의 호환을 위해 채운다.
      alertPort: BackgroundAlertNotifier(
        plugin: FlutterLocalNotificationsPlugin(),
        store: PendingAlertStore(),
      ),
      idGenerator: IdGenerator.generate,
      clock: DateTime.now,
    ),
    store: PendingAlertStore(),
  );

  const channel = MethodChannel('kr.suhsaechan.ear_loc_alert/watch_engine');

  channel.setMethodCallHandler((call) async {
    try {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'evaluatePosition':
          final decision = await host.onPosition(
            latitude: (args['latitude'] as num).toDouble(),
            longitude: (args['longitude'] as num).toDouble(),
            accuracyMeters: (args['accuracyMeters'] as num).toDouble(),
            timestampUtc: DateTime.fromMillisecondsSinceEpoch(
              (args['timestampMs'] as num).toInt(),
              isUtc: true,
            ),
          );
          return decision.toMap();
        case 'evaluateOsTransition':
          final decision = await host.onOsTransition(
            placeId: args['placeId'] as String,
            entered: args['entered'] as bool,
            latitude: (args['latitude'] as num?)?.toDouble(),
            longitude: (args['longitude'] as num?)?.toDouble(),
          );
          return decision.toMap();
        default:
          return null;
      }
    } on Object {
      // 인자가 깨져 있어도 감시는 계속되어야 한다.
      // 좌표가 담길 수 있으므로 로그도 남기지 않는다 (docs/04-CONVENTIONS.md)
      return const {'shouldAlert': false};
    }
  });

  // 네이티브에 준비 완료를 알린다 — 이 신호 전에 온 요청은 서비스가 큐에
  // 담아두었다가 여기서 흘려보낸다. 버리면 그 도착이 유실된다.
  channel.invokeMethod<void>('engineReady');
}
