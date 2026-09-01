import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/audio_session_headphone_detector.dart';
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

  /// 장소가 음원을 지정하지 않았을 때 쓰는 소리
  final String _defaultAssetPath;
  final HeadphoneDetector _detector;
  AudioPlayer? _player;

  @override
  Future<bool> isHeadphoneConnected() => _detector.isConnected();

  @override
  Future<void> play({required double volume, AlertSoundSource? source}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);

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

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object {
      // 중단 실패를 삼킨다 — 해제는 항상 완료되어야 한다
    }
  }
}
