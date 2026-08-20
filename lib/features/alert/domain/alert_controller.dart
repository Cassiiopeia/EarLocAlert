import 'dart:async';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/domain/alert_direction.dart';
import 'alert_effects.dart';
import 'alert_session.dart';
import 'audio_route.dart';
import 'vibration_intensity.dart';

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
    required AlertVolumeStore volumeStore,
    required SystemVolumeService systemVolume,
    VibrationIntensityStore? vibrationStore,
  }) : _vibration = vibration,
       _sound = sound,
       _notifier = notifier,
       _routeDecider = routeDecider,
       _volumeStore = volumeStore,
       _systemVolume = systemVolume,
       _vibrationStore = vibrationStore;

  final VibrationService _vibration;
  final AlertSoundService _sound;
  final AlertNotifier _notifier;
  final AudioRouteDecider _routeDecider;
  final AlertVolumeStore _volumeStore;
  final SystemVolumeService _systemVolume;

  /// 진동 세기 설정 (이슈 #103).
  ///
  /// 없으면 기본 세기로 돈다 — 설정 하나를 못 읽었다고 알림이 멎으면 안
  /// 된다. 기존 테스트가 이 인자 없이 컨트롤러를 만들 수 있게도 한다.
  final VibrationIntensityStore? _vibrationStore;

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
      // 같은 장소면 버리고 다른 장소면 줄 세운다 — 왜 안 울렸는지의
      // 흔한 답이 "이미 울리는 중이었다"다 (이슈 #106)
      if (active.placeId != request.placeId) {
        _queue.add(request);
        Diagnostics.log(
          'alert',
          '이미 울리는 중 — 대기열 추가 place=${request.placeName} '
              '(현재=${active.placeName}, 대기 ${_queue.length}건)',
        );
      } else {
        Diagnostics.log('alert', '같은 장소 재발화 무시 place=${request.placeName}');
      }
      return null;
    }
    return _start(request, vibrationInterval: vibrationInterval);
  }

  /// 설정된 진동 세기를 읽는다 (이슈 #103).
  ///
  /// **실패해도 진동은 돈다.** 설정을 못 읽는 것은 세기가 기본값이 되는
  /// 일이지 알림이 멎을 일이 아니다.
  Future<VibrationIntensity> _readIntensity() async {
    final store = _vibrationStore;
    if (store == null) return VibrationIntensity.normal;
    try {
      return await store.intensity();
    } on Object {
      return VibrationIntensity.normal;
    }
  }

  Future<AlertSession> _start(
    AlertRequest request, {
    required Duration vibrationInterval,
  }) async {
    final intensity = await _readIntensity();
    Diagnostics.log(
      'alert',
      '세션 시작 place=${request.placeName} '
          'direction=${request.direction.name} '
          'sound=${request.soundEnabled} vibration=${intensity.name}',
    );

    // 진동이 먼저다 — 소리 판정이 오래 걸려도 알림은 이미 전달된다
    await _vibration.startRepeating(
      interval: vibrationInterval,
      intensity: intensity,
    );
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
      connected = await _sound.isHeadphoneConnected();
    } on Object {
      // 연결 확인이 실패하면 연결되지 않은 것으로 본다.
      // 확인 못 한 상태로 재생하면 스피커로 샐 수 있다.
      connected = false;
    }

    if (_sessionToken != token) return; // 이미 해제됐다

    final route = _routeDecider.decide(
      isHeadphoneConnected: connected,
      soundEnabled: request.soundEnabled,
    );

    // **소리가 났는지 안 났는지가 이 앱에서 가장 자주 묻는 질문이다**
    // (이슈 #106). 이어폰 연결과 장소 설정 중 무엇 때문에 조용했는지
    // 로그 없이는 가릴 수 없다
    Diagnostics.log(
      'alert',
      '오디오 판정 이어폰=$connected 장소설정=${request.soundEnabled} '
          '결과=${route.name}',
    );

    if (route == AudioRoute.silent) return; // 세션은 이미 silent 다

    try {
      // 설정 읽기 실패가 알림음을 없애면 안 된다 — 기본값으로 간다
      var volume = AlertVolumeStore.defaultVolume;
      try {
        volume = await _volumeStore.volume();
      } on Object {
        // 기본값 유지
      }

      // 시스템 볼륨이 0 이면 앱 볼륨을 아무리 올려도 무음이다 (이슈 #86).
      // 설정값 수준까지 끌어올린다 — 이어폰 경로가 확정된 뒤라 스피커로
      // 새지 않고, 해제 시 _silence() 가 되돌린다. iOS 는 no-op 이다.
      await _systemVolume.raiseTo(volume);
      if (_sessionToken != token) {
        // 올리는 사이 해제됐다 — 원복은 _silence() 가 이미 했을 수도,
        // 아직일 수도 있다. 한 번 더 되돌려도 해가 없다(원복은 멱등이다).
        await _systemVolume.restore();
        return;
      }

      await _sound.play(volume: volume);
      if (_sessionToken != token) return;
      _updateRoute(AudioRoute.headphones, soundFailed: false);
    } on Object catch (error) {
      // 재시도하지 않는다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이
      // 최악이다 (docs/10-DECISIONS.md 007)
      if (_sessionToken != token) return;
      Diagnostics.log('alert', '알림음 재생 실패 — 진동으로 떨어짐 $error');
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

    Diagnostics.log(
      'alert',
      '세션 해제 place=${session.placeName} 대기 ${_queue.length}건',
    );

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
      Diagnostics.log('alert', '대기 알림 이어서 발화 place=${next.placeName}');
      await _start(next, vibrationInterval: vibrationInterval);
    }

    return session;
  }

  Future<void> _silence() async {
    // 시스템 볼륨 원복이 여기 있다 (이슈 #86) — 올린 채로 두면 사용자의
    // 기기 설정을 앱이 영구히 바꾼 것이 된다. 올린 적이 없으면 no-op 이다.
    for (final stop in [
      _vibration.stop,
      _sound.stop,
      _systemVolume.restore,
      _notifier.dismiss,
    ]) {
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
