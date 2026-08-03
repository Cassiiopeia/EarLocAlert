import '../../../core/domain/alert_direction.dart';
import 'alert_effects.dart';
import 'alert_session.dart';
import 'audio_route.dart';

/// 알림 발화 요청 — feature 간 값 전달 (docs/02-ARCHITECTURE.md 규칙 1)
///
/// `alert` 는 `places` 를 import 하지 않는다. 필요한 값만 받는다.
class AlertRequest {
  const AlertRequest({
    required this.placeId,
    required this.placeName,
    required this.direction,
    required this.soundEnabled,
    required this.occurredAt,
  });

  final String placeId;
  final String placeName;

  /// 진입인지 이탈인지 — 화면 표시에 쓴다
  final AlertDirection direction;

  final bool soundEnabled;
  final DateTime occurredAt;
}

/// 알림 발화·해제 조율 (docs/03-DOMAIN.md 규칙 4·5)
///
/// **플랫폼 API 를 직접 부르지 않는다.** 전부 인터페이스 뒤에 있어
/// 실기기 없이 흐름 전체를 테스트할 수 있다.
class AlertController {
  AlertController({
    required VibrationService vibration,
    required AlertSoundService sound,
    required AlertNotifier notifier,
    required AudioRouteDecider routeDecider,
  }) : _vibration = vibration,
       _sound = sound,
       _notifier = notifier,
       _routeDecider = routeDecider;

  final VibrationService _vibration;
  final AlertSoundService _sound;
  final AlertNotifier _notifier;
  final AudioRouteDecider _routeDecider;

  AlertSession? _current;
  final List<AlertRequest> _queue = [];

  /// 지금 울리고 있는 알림. 없으면 null
  AlertSession? get current => _current;

  /// 해제를 기다리는 다른 장소의 알림 수
  int get queuedCount => _queue.length;

  /// 알림을 발화한다.
  ///
  /// 규칙 4 — 이미 울리고 있으면:
  /// - **같은 장소**의 이벤트는 무시한다
  /// - **다른 장소**는 대기열에 넣고 해제 후 처리한다
  ///
  /// 알림 두 개가 동시에 진동·소리를 내면 사용자는 무엇을 해제해야 하는지
  /// 알 수 없다.
  Future<AlertSession?> fire(
    AlertRequest request, {
    required Duration vibrationInterval,
  }) async {
    final active = _current;
    if (active != null) {
      if (active.placeId != request.placeId) _queue.add(request);
      return null;
    }
    return _start(request, vibrationInterval: vibrationInterval);
  }

  Future<AlertSession> _start(
    AlertRequest request, {
    required Duration vibrationInterval,
  }) async {
    final outcome = await _playEffects(request, vibrationInterval);

    final session = AlertSession(
      placeId: request.placeId,
      placeName: request.placeName,
      direction: request.direction,
      startedAt: request.occurredAt,
      audioRoute: outcome.audioRoute,
    );
    _current = session;
    return session;
  }

  /// 규칙 5 — 오디오 경로는 **발화 시점에** 결정한다.
  ///
  /// 어떤 분기로도 스피커 출력이 없다 (F3.7).
  Future<AlertOutcome> _playEffects(
    AlertRequest request,
    Duration vibrationInterval,
  ) async {
    // 진동이 먼저다 — 소리 판정이 오래 걸려도 알림은 이미 전달된다
    await _vibration.startRepeating(interval: vibrationInterval);
    await _notifier.show(
      placeName: request.placeName,
      body: request.direction == AlertDirection.exit ? '떠났습니다' : '도착했습니다',
    );

    var connected = false;
    try {
      connected = await _sound.isBluetoothConnected();
    } on Object {
      // 연결 확인이 실패하면 연결되지 않은 것으로 본다.
      // 확인 못 한 상태로 재생하면 스피커로 샐 수 있다.
      connected = false;
    }

    final route = _routeDecider.decide(
      isBluetoothConnected: connected,
      soundEnabled: request.soundEnabled,
    );

    if (route == AudioRoute.silent) {
      return const AlertOutcome(
        audioRoute: AudioRoute.silent,
        soundFailed: false,
      );
    }

    try {
      await _sound.play();
      return const AlertOutcome(
        audioRoute: AudioRoute.bluetooth,
        soundFailed: false,
      );
    } on Object {
      // 재시도하지 않는다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이
      // 최악이다 (docs/10-DECISIONS.md 007)
      return AlertOutcome(
        audioRoute: _routeDecider.onPlaybackFailure(),
        soundFailed: true,
      );
    }
  }

  /// 알림을 해제한다.
  ///
  /// **이 메서드는 어떤 이유로도 지연되지 않는다** (docs/02-ARCHITECTURE.md
  /// 규칙 4). 진동·소리·알림 중단이 개별적으로 실패해도 나머지는 계속 진행하고,
  /// 세션은 반드시 정리된다.
  ///
  /// 해제된 세션을 반환한다. 울리고 있지 않았으면 null.
  Future<AlertSession?> dismiss({
    Duration vibrationInterval = const Duration(seconds: 3),
  }) async {
    final session = _current;
    if (session == null) return null;

    // 하나가 실패해도 나머지를 멈추지 않는다
    await _silence();
    _current = null;

    // 대기 중이던 다른 장소의 알림을 이어서 처리한다
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      await _start(next, vibrationInterval: vibrationInterval);
    }

    return session;
  }

  Future<void> _silence() async {
    for (final stop in [_vibration.stop, _sound.stop, _notifier.dismiss]) {
      try {
        await stop();
      } on Object {
        // 개별 실패를 삼킨다 — 해제는 무슨 일이 있어도 완료되어야 한다
      }
    }
  }

  /// 대기열을 비운다. 앱 종료·설정 변경 시 사용
  void clearQueue() => _queue.clear();
}
