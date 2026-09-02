import '../../core/diagnostics/diagnostics.dart';
import '../../features/alert/domain/vibration_intensity.dart';
import '../../features/geofence/domain/geofence_event.dart';
import '../../features/geofence/domain/position_sample.dart';
import 'alert_decision.dart';
import 'geofence_background_processor.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';

/// 감시 서비스 엔진의 Dart 진입점 (이슈 #93)
///
/// 네이티브 `AlertWatchService` 가 보유한 FlutterEngine 위에서 산다.
/// **UI 가 없다** — BuildContext·위젯 트리 Provider 접근 금지
/// (docs/02-ARCHITECTURE.md 규칙 5).
///
/// 하는 일은 셋뿐이다: 채널의 원시 값을 도메인 타입으로 바꾸고, 판정을
/// [GeofenceBackgroundProcessor] 에 위임하고, 결과를 네이티브가 읽을
/// 형태로 되돌린다. **판정 규칙을 여기 두지 않는다** — 규칙이 두 곳에
/// 생기면 반드시 어긋난다 (docs/03-DOMAIN.md 규칙 5).
///
/// 어떤 예외도 밖으로 던지지 않는다. 백그라운드 크래시는 사용자에게
/// 보이지 않은 채 감시만 죽인다.
class WatchEngineHost {
  WatchEngineHost({
    required GeofenceBackgroundProcessor processor,
    required PendingAlertStore store,
    VibrationIntensityStore? vibrationStore,
  }) : _processor = processor,
       _store = store,
       _vibrationStore = vibrationStore;

  final GeofenceBackgroundProcessor _processor;
  final PendingAlertStore _store;

  /// 진동 세기 설정 (이슈 #103).
  ///
  /// 네이티브가 설정을 직접 읽지 않고 판정 결과에 실어 보낸다 — 설정을
  /// 읽는 자리가 둘이 되면 반드시 어긋난다.
  final VibrationIntensityStore? _vibrationStore;

  /// 정밀 모드 위치 측정 하나를 판정한다.
  ///
  /// 근접 반경 안에 있는 동안 서비스가 몇 초 간격으로 부른다.
  Future<AlertDecision> onPosition({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime timestampUtc,
  }) {
    // 좌표를 남긴다 (이슈 #95) — "왜 이 장소가 판정되지 않았는가"는
    // 좌표 없이 추적할 수 없고, 그것이 가장 자주 묻게 되는 질문이다.
    // 로그는 앱 전용 디렉토리에만 있고 어디로도 전송하지 않는다.
    // 좌표와 판정 결과를 한 줄로 합쳤다 (이슈 #127) —
    // `GeofenceBackgroundProcessor.handlePosition` 이 남긴다.
    return _decide(
      () => _processor.handlePosition(
        sample: PositionSample(
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          timestamp: timestampUtc,
        ),
      ),
    );
  }

  /// OS 지오펜스 전이를 판정한다 — **폴백 경로**.
  ///
  /// 정밀 감시가 죽어 있어도(권한 취소·스트림 오류) 이 경로로 알림이
  /// 나간다. 두 경로가 같은 상태 저장소를 보므로, 어느 쪽이 먼저
  /// 도착하든 두 번째는 전이가 없어 조용히 넘어간다.
  Future<AlertDecision> onOsTransition({
    required String placeId,
    required bool entered,
    double? latitude,
    double? longitude,
  }) {
    Diagnostics.log(
      'geofence',
      'OS 전이 수신 place=$placeId ${entered ? "ENTER" : "EXIT"} '
          'lat=$latitude lng=$longitude',
    );
    return _decide(
      () => _processor.handleTransition(
        placeId: placeId,
        eventType: entered
            ? GeofenceEventType.entered
            : GeofenceEventType.exited,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<AlertDecision> _decide(
    Future<PendingAlert?> Function() evaluate,
  ) async {
    try {
      final alert = await evaluate();
      if (alert == null) {
        // 사유는 판정 지점이 남긴다 (이슈 #127) — 여기서 한 번 더
        // "알림 없음"만 찍으면 정보 없는 줄이 두 배가 된다
        return AlertDecision.none;
      }

      // 저장이 먼저다 — 화면이 뜬 뒤 AlertController 가 이 값으로 반복
      // 진동·이어폰 판정·소리까지 이어받는다 (이슈 #63)
      await _store.save(alert);

      final intensity = await _readIntensity();

      Diagnostics.log(
        'engine',
        '알림 발생 place=${alert.placeId} name=${alert.placeName} '
            'direction=${alert.direction.name} sound=${alert.soundEnabled} '
            'vibration=${intensity.name}',
      );

      return AlertDecision(
        shouldAlert: true,
        placeId: alert.placeId,
        placeName: alert.placeName,
        direction: alert.direction.name,
        soundEnabled: alert.soundEnabled,
        vibrationAmplitude: intensity.amplitude,
        vibrationPulseMs: intensity.pulseMs,
      );
    } on Object catch (error) {
      // 예외를 삼키되 **기록은 남긴다** (이슈 #95).
      // 예전에는 좌표 노출을 우려해 아무것도 안 남겼고, 그래서 백그라운드
      // 실패를 추적할 방법이 통째로 없었다.
      Diagnostics.log('engine', '판정 실패 $error');
      return AlertDecision.none;
    }
  }

  /// 설정된 진동 세기를 읽는다 (이슈 #103).
  ///
  /// **실패해도 알림은 나간다.** 설정 하나 못 읽은 것이 도착 알림을
  /// 삼키면 안 된다 — 기본 세기로 떨어진다.
  Future<VibrationIntensity> _readIntensity() async {
    final store = _vibrationStore;
    if (store == null) return VibrationIntensity.normal;
    try {
      return await store.intensity();
    } on Object catch (error) {
      Diagnostics.log('engine', '진동 세기 조회 실패 $error');
      return VibrationIntensity.normal;
    }
  }
}
