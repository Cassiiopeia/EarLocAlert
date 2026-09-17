import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/audio_session_headphone_detector.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/audio/headphone_detector.dart';
import '../domain/alert_effects.dart';

/// 알림음 재생 구현 (docs/10-DECISIONS.md 007·018)
///
/// **이 클래스의 목적은 소리를 내는 것이 아니라 스피커로 새지 않게 하는 것이다.**
///
/// 두 OS 모두 이어폰이 연결되어 있으면 미디어가 자동으로 그리로 간다.
/// 앱이 라우팅을 조작할 필요가 없다 — 해야 할 일은 반대로,
/// **연결되어 있지 않으면 재생하지 않는 것**이다.
class AlertSoundServiceImpl implements AlertSoundService {
  AlertSoundServiceImpl({String? assetPath, HeadphoneDetector? detector})
    : _defaultAssetPath = assetPath ?? 'assets/sounds/alert.wav',
      _detector = detector ?? const AudioSessionHeadphoneDetector();

  /// 이어폰 허용 목록 — **실제 정의는 `core/audio` 에 하나만 있다.**
  ///
  /// 미리듣기(`sounds` feature)도 같은 판정을 써야 하는데 feature 끼리는
  /// 직접 import 할 수 없어 `core` 로 올렸다 (이슈 #121).
  /// 이 별칭은 기존 테스트가 보던 이름이다.
  static const headphoneTypes = AudioSessionHeadphoneDetector.headphoneTypes;

  /// 알림 전용 오디오 세션 (이슈 #129)
  ///
  /// **`AudioSessionConfiguration.speech()` 를 쓰면 안 된다.** 그 프리셋은
  /// `androidWillPauseWhenDucked: true` 라서, 다른 앱이 우리를 duck 시키면
  /// **우리 재생이 멈춘다.** 넷플릭스를 보던 중 알림이 0.5초만 들리고
  /// 사라진 것이 정확히 그 동작이었다.
  ///
  /// 알림은 ducked 되어도 계속 울려야 한다 — 작아질지언정 멈추면
  /// 사용자가 내릴 정거장을 놓친다.
  /// 테스트에서 값을 검증한다 — 오디오 포커스는 실기기로만 확인되지만
  /// **설정이 되돌아가는 것은 막을 수 있다** (이슈 #129).
  static const alertSessionConfiguration = AudioSessionConfiguration(
    // iOS — 옵션을 주지 않으면 다른 앱이 중단된다
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      // 알림음이지 음성이 아니다
      contentType: AndroidAudioContentType.sonification,
      // **`alarm` 을 쓰지 않는다 — 스피커로 샐 수 있다.**
      //
      // Android 는 알람·벨소리 계열을 "놓치면 안 되는 소리"로 취급해,
      // **이어폰이 연결돼 있어도 스피커로 함께 내보내는 기기가 있다**
      // (제조사 커스터마이징에서 흔하다). 이 앱에서 그것은 존재 이유를
      // 잃는 사고다 (CLAUDE.md 금지 2).
      //
      // 미디어 스트림은 그런 동작이 없다 — 이어폰이 있으면 이어폰으로만 간다.
      // **다른 앱을 멈추는 것은 usage 가 아니라 포커스 타입이 한다** —
      // 아래 `gainTransient` 가 그 역할이다.
      usage: AndroidAudioUsage.media,
    ),
    // 해제하면 원래 앱이 재개되어야 한다 — gain 은 영구 점유라 재개되지 않는다
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
    // **ducked 되어도 멈추지 않는다.** 이 한 줄이 이슈 #129 의 핵심이다
    androidWillPauseWhenDucked: false,
  );

  /// 장소가 음원을 지정하지 않았을 때 쓰는 소리
  final String _defaultAssetPath;
  final HeadphoneDetector _detector;
  AudioPlayer? _player;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;

  @override
  Future<bool> isHeadphoneConnected() => _detector.isConnected();

  @override
  Future<void> play({required double volume, AlertSoundSource? source}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(alertSessionConfiguration);

      // **포커스 획득 결과를 확인한다** (이슈 #129). 예전에는 반환값을
      // 버려서, 다른 앱이 배타적으로 점유해 요청이 거부돼도 그냥 재생을
      // 시작했다. 거부되어도 재생은 시도한다 — 작게라도 나는 편이
      // 아예 없는 것보다 낫고, 진동은 이미 울리고 있다.
      final granted = await session.setActive(true);
      Diagnostics.log(
        'alert',
        '오디오 포커스 ${granted ? "획득" : "거부"} (거부여도 재생은 시도한다)',
      );
      _listenInterruptions(session);

      final player = _player ??= AudioPlayer();
      // 사용자가 설정한 알림음 크기 (이슈 #86). 재생 시작 전에 걸어야
      // 첫 소리부터 그 크기다 — 큰 소리가 한 번 나가고 줄어드는 것은 늦다.
      await player.setVolume(volume.clamp(0.0, 1.0));

      // 음원 로딩까지는 기다린다 — 여기서 실패해야 진동으로 떨어질 수 있다.
      // 장소마다 다른 음원이 여기서 갈린다 (이슈 #121).
      switch (source) {
        case AssetSound(:final assetPath):
          await player.setAsset(assetPath);
        case FileSound(:final filePath):
          // 경로 유효성은 app 의 해석기가 이미 확인했다. 그래도 실패하면
          // 아래 catch 가 받아 진동으로 떨어진다.
          await player.setFilePath(filePath);
        case null:
          await player.setAsset(_defaultAssetPath);
      }

      // 해제할 때까지 반복한다. 진동이 반복되는 동안 소리만 한 번 나고
      // 마는 것은 알림으로서 약하다 — 졸다 깬 사용자가 놓친다.
      await player.setLoopMode(LoopMode.one);

      // **play() 를 기다리지 않는다.** 이 Future 는 재생이 *끝날 때* 완료되는데,
      // 반복 재생은 해제 전까지 끝나지 않는다. 기다리면 호출자가 영원히
      // 막혀 화면이 "이어폰으로 알림 중"으로 바뀌지 못한다.
      //
      // 다만 에러는 삼켜야 한다. 기다리지 않는 Future 가 실패하면 처리되지 않은
      // 비동기 예외가 되어 앱 전역으로 번진다. 여기서 실패해도 진동은
      // 이미 울리고 있고, 해제는 영향을 받지 않는다.
      unawaited(player.play().catchError((Object _) {}));
    } on Object catch (error) {
      // 호출자는 이 예외를 받아 재시도 없이 진동으로 떨어진다
      throw AlertSoundException('$error');
    }
  }

  /// 재생 중 방해받은 사실을 남긴다 (이슈 #129).
  ///
  /// **이 기록이 없어서 원인을 코드에서 찾아야 했다.** 로그에는 재생을
  /// 시작한 줄까지만 있고, 포커스를 뺏겨 멈춘 사실은 어디에도 없었다.
  ///
  /// 구독은 한 번만 건다 — 알림마다 새로 걸면 리스너가 쌓인다.
  void _listenInterruptions(AudioSession session) {
    if (_interruptions != null) return;
    _interruptions = session.interruptionEventStream.listen((event) {
      Diagnostics.log(
        'alert',
        '오디오 중단 ${event.begin ? "시작" : "종료"} 유형=${event.type.name}',
      );
    });
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object {
      // 중단 실패를 삼킨다 — 해제는 항상 완료되어야 한다
    }

    // **오디오 포커스를 반납한다** (이슈 #136).
    //
    // `gainTransient` 는 "잠깐 빌린다"는 뜻이라 놓아야 원래 앱이
    // 재개된다. 빌리기만 하고 반납하지 않으면 알림을 꺼도 넷플릭스가
    // 돌아오지 않는다 — 이슈 #129 에서 `gain` 대신 이것을 고른 이유가
    // 무색해진다.
    //
    // **재생을 멈춘 뒤에 놓는다.** 순서가 뒤집히면 재생 중에 포커스를
    // 놓는 것이 된다.
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } on Object {
      // 반납 실패도 삼킨다 — 해제는 무슨 일이 있어도 완료되어야 한다
    }
  }
}
