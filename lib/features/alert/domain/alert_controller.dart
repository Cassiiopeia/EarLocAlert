import 'dart:async';

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
  final _sessionChanges = StreamController<AlertSession?>.broadcast();

  /// 세션 토큰. 재생 결과가 늦게 도착했을 때 이미 해제된 세션을
  /// 되살리지 않도록 구분한다.
  int _sessionToken = 0;

  /// 지금 울리고 있는 알림. 없으면 null
  AlertSession? get current => _current;

  /// 세션 변화 스트림.
  ///
  /// 오디오 경로는 발화 직후 확정되지 않을 수 있어(재생이 늦게 실패)
  /// 화면이 이것을 구독해 표시를 갱신한다.
  Stream<AlertSession?> get sessionChanges => _sessionChanges.stream;

  /// 마지막 발화에서 소리 재생이 실패했는가
  bool get lastSoundFailed => _lastSoundFailed;
  bool _lastSoundFailed = false;

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
    // 진동이 먼저다 — 소리 판정이 오래 걸려도 알림은 이미 전달된다
    await _vibration.startRepeating(interval: vibrationInterval);
    await _notifier.show(
      placeName: request.placeName,
      body: request.direction == AlertDirection.exit ? '떠났습니다' : '도착했습니다',
    );

    // **세션을 오디오 판정 전에 만든다.**
    //
    // 진동이 시작된 순간부터 해제가 가능해야 한다. 오디오 재생을
    // 기다렸다가 세션을 만들면, 재생이 지연되는 동안 사용자가 해제를 눌러도
    // 아무 일도 일어나지 않아 진동이 계속된다 (docs/02-ARCHITECTURE.md 규칙 4).
    final token = ++_sessionToken;
    final session = AlertSession(
      placeId: request.placeId,
      placeName: request.placeName,
      direction: request.direction,
      startedAt: request.occurredAt,
      // 판정 전이므로 보수적으로 무음에서 시작한다 —
      // 실제로 이어폰 재생이 확정되면 갱신한다
      audioRoute: AudioRoute.silent,
    );
    _current = session;
    _lastSoundFailed = false;
    _sessionChanges.add(session);

    // 오디오는 알림 전달을 막지 않는다. 결과가 늦게 와도
    // 이미 해제됐으면 무시한다.
    unawaited(_resolveAudio(request, token));

    return session;
  }

  /// 규칙 5 — 오디오 경로는 **발화 시점에** 결정한다.
  ///
  /// 어떤 분기로도 스피커 출력이 없다 (F3.7).
  Future<void> _resolveAudio(AlertRequest request, int token) async {
    var connected = false;
    try {
      connected = await _sound.isBluetoothConnected();
    } on Object {
      // 연결 확인이 실패하면 연결되지 않은 것으로 본다.
      // 확인 못 한 상태로 재생하면 스피커로 샐 수 있다.
      connected = false;
    }

    if (_sessionToken != token) return; // 이미 해제됐다

    final route = _routeDecider.decide(
      isBluetoothConnected: connected,
      soundEnabled: request.soundEnabled,
    );
    if (route == AudioRoute.silent) return; // 세션은 이미 silent 다

    try {
      await _sound.play();
      if (_sessionToken != token) return;
      _updateRoute(AudioRoute.bluetooth, soundFailed: false);
    } on Object {
      // 재시도하지 않는다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이
      // 최악이다 (docs/10-DECISIONS.md 007)
      if (_sessionToken != token) return;
      _updateRoute(_routeDecider.onPlaybackFailure(), soundFailed: true);
    }
  }

  void _updateRoute(AudioRoute route, {required bool soundFailed}) {
    final session = _current;
    if (session == null) return;
    _lastSoundFailed = soundFailed;
    _current = session.copyWith(audioRoute: route);
    _sessionChanges.add(_current);
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

    // 토큰을 먼저 무효화한다 — 진행 중인 오디오 판정 결과가
    // 뒤늦게 도착해도 해제된 세션을 되살리지 못한다
    _sessionToken++;
    _current = null;

    // 하나가 실패해도 나머지를 멈추지 않는다
    await _silence();
    _sessionChanges.add(null);

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

  void dispose() => _sessionChanges.close();
}
