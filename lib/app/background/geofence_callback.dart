import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:native_geofence/native_geofence.dart' as ng;

import '../../core/database/app_database.dart';
import '../../core/domain/id_generator.dart';
import '../../features/geofence/data/drift_geofence_event_repository.dart';
import '../../features/geofence/data/drift_geofence_state_repository.dart';
import '../../features/geofence/domain/geofence_evaluator.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/places/data/drift_place_repository.dart';
import 'background_alert_notifier.dart';
import 'geofence_background_processor.dart';
import 'pending_alert_store.dart';

/// OS 지오펜스 이벤트의 백그라운드 진입점 (이슈 #63)
///
/// 앱이 종료된 상태에서도 OS 가 전용 isolate 에서 이 함수를 부른다.
/// **UI 가 없다** — BuildContext·위젯 트리 Provider 접근 금지
/// (docs/02-ARCHITECTURE.md 규칙 5). Riverpod 컨테이너도 없으므로
/// 의존성을 여기서 직접 조립한다.
///
/// 어떤 예외도 밖으로 던지지 않는다 — 백그라운드 크래시는 사용자에게
/// 보이지 않은 채 감시만 죽인다.
@pragma('vm:entry-point')
Future<void> geofenceBackgroundCallback(
  ng.GeofenceCallbackParams params,
) async {
  // isolate 마다 DB 를 새로 열고 반드시 닫는다 — 짧은 콜백 수명에
  // 연결을 남기면 다음 콜백이 잠금에 걸릴 수 있다
  final db = AppDatabase();
  try {
    // 이 isolate 는 앱 부트스트랩을 거치지 않았다 — 플러그인을 직접
    // 초기화해야 알림 발행이 된다
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final processor = GeofenceBackgroundProcessor(
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

    final eventType = params.event == ng.GeofenceEvent.exit
        ? GeofenceEventType.exited
        // dwell 은 등록하지 않지만 방어적으로 enter 로 취급한다
        : GeofenceEventType.entered;

    // Android 는 여러 지오펜스가 한 이벤트로 묶여 올 수 있다
    for (final geofence in params.geofences) {
      try {
        await processor.handle(
          placeId: geofence.id,
          eventType: eventType,
          latitude: params.location?.latitude,
          longitude: params.location?.longitude,
        );
      } on Object {
        // 한 장소의 실패가 다른 장소 처리를 막으면 안 된다.
        // 좌표가 담길 수 있으므로 로그도 남기지 않는다 (docs/04 규칙)
      }
    }
  } on Object {
    // 조립 실패까지 삼킨다 — 위 주석과 같은 이유
  } finally {
    await db.close();
  }
}
