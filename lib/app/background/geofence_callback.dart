import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:native_geofence/native_geofence.dart' as ng;

import '../../core/database/app_database.dart';
import '../../core/diagnostics/diagnostic_log_file.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/domain/id_generator.dart';
import '../../features/geofence/data/drift_geofence_event_repository.dart';
import '../../features/geofence/data/drift_geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/places/data/drift_place_repository.dart';
import 'background_alert_notifier.dart';
import 'geofence_background_processor.dart';
import 'pending_alert_store.dart';
import 'region_event_relay.dart';

/// OS 지오펜스 이벤트의 백그라운드 진입점 (이슈 #63, #231)
///
/// 앱이 종료된 상태에서도 OS 가 전용 isolate 에서 이 함수를 부른다.
/// **UI 가 없다** — BuildContext·위젯 트리 Provider 접근 금지
/// (docs/02-ARCHITECTURE.md 규칙 5). Riverpod 컨테이너도 없으므로
/// 의존성을 여기서 직접 조립한다.
///
/// **같은 isolate 에 동시에 여러 번 불린다** (이슈 #231). 판정은 isolate 에
/// 하나뿐인 [_handler] 의 큐로 줄 세우고, 모든 작업이 끝날 때까지 돌아가지
/// 않는다 — 먼저 끝난 콜백이 엔진 파괴를 부르면 나머지가 기록 없이 사라진다.
///
/// 어떤 예외도 밖으로 던지지 않는다 — 백그라운드 크래시는 사용자에게
/// 보이지 않은 채 감시만 죽인다.
@pragma('vm:entry-point')
Future<void> geofenceBackgroundCallback(
  ng.GeofenceCallbackParams params,
) async {
  // 이 isolate 는 앱 부트스트랩을 거치지 않는다 — 여기서 켜지 않으면 판정 로그가
  // 전부 버려진다 (이슈 #213). 앱 isolate 와 파일을 나눈다 (이슈 #231)
  await Diagnostics.init(source: DiagnosticLogSource.background);
  Diagnostics.log(
    'geofence',
    'ios callback received event=${params.event.name} '
        'ids=${params.geofences.map((g) => g.id).join(",")} '
        'lat=${params.location?.latitude} lng=${params.location?.longitude}',
  );

  // dwell 은 등록하지 않지만 방어적으로 enter 로 취급한다
  final entered = params.event != ng.GeofenceEvent.exit;
  try {
    await _handler.handle([
      // Android 는 여러 지오펜스가 한 이벤트로 묶여 올 수 있다
      for (final geofence in params.geofences)
        RegionEvent(
          placeId: geofence.id,
          entered: entered,
          latitude: params.location?.latitude,
          longitude: params.location?.longitude,
        ),
    ]);
  } on Object catch (error) {
    Diagnostics.log('geofence', 'ios callback failed error=$error');
  } finally {
    // 큐가 비었으면 연결을 닫는다 — 엔진이 파괴되면 isolate 와 함께 연결이 새고,
    // 앱 isolate 의 연결과 오래 겹칠 이유도 없다. 다음 콜백이 다시 연다
    await _LocalContext.closeIfIdle();
  }
}

/// isolate 에 하나 — 콜백 사이를 줄 세우는 것이 이것의 존재 이유다
final _handler = RegionCallbackHandler(
  // 앱 isolate 가 살아 있으면 그쪽 판정기로 넘긴다 — 정밀 판정과 같은 큐를 탄다
  relay: relayRegionEventToApp,
  handleLocally: (event) async {
    final processor = await _LocalContext.processor();
    await processor.handle(
      placeId: event.placeId,
      eventType: event.entered
          ? GeofenceEventType.entered
          : GeofenceEventType.exited,
      latitude: event.latitude,
      longitude: event.longitude,
    );
  },
);

/// 앱 isolate 가 없을 때 직접 판정하는 데 쓰는 의존성 (이슈 #231)
///
/// 콜백마다 새로 만들지 않는다 — 판정기의 직전 측정 기억과 직렬화가 콜백
/// 사이에서도 이어져야 한다. 큐가 비면 닫고 다음에 다시 연다.
abstract final class _LocalContext {
  static AppDatabase? _db;
  static GeofenceBackgroundProcessor? _processor;

  static Future<GeofenceBackgroundProcessor> processor() async {
    final existing = _processor;
    if (existing != null) return existing;

    final db = AppDatabase();
    // 이 isolate 는 앱 부트스트랩을 거치지 않았다 — 플러그인을 직접
    // 초기화해야 알림 발행이 된다
    final plugin = FlutterLocalNotificationsPlugin();
    await ensureNotificationsInitialized(plugin);
    final created = GeofenceBackgroundProcessor(
      places: DriftPlaceRepository(db),
      states: DriftGeofenceStateRepository(db),
      events: DriftGeofenceEventRepository(db),
      evaluator: const GeofenceEvaluator(),
      alertPort: BackgroundAlertNotifier(
        plugin: plugin,
        store: PendingAlertStore(),
      ),
      idGenerator: IdGenerator.generate,
      clock: DateTime.now,
    );
    _db = db;
    _processor = created;
    return created;
  }

  static Future<void> closeIfIdle() async {
    final db = _db;
    if (db == null) return;
    // 다른 콜백이 아직 이 연결로 판정 중이면 닫지 않는다 — 마지막 콜백이 닫는다
    if (_handler.pending > 0) return;
    _db = null;
    _processor = null;
    try {
      await db.close();
    } on Object catch (error) {
      Diagnostics.log('geofence', 'callback db close failed error=$error');
    }
  }
}
