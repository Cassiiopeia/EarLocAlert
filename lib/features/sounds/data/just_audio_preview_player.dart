import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../../core/audio/alert_sound_source.dart';
import '../domain/sound_preview_player.dart';

/// `just_audio` 기반 미리듣기 (이슈 #121)
///
/// **오디오 세션을 건드리지 않는다.** 알림은 `speech` 설정으로 세션을
/// 점유하지만 미리듣기는 그럴 이유가 없고, 알림이 울리는 도중 미리듣기가
/// 세션을 바꾸면 알림 쪽 재생이 흔들린다.
class JustAudioPreviewPlayer implements SoundPreviewPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play(AlertSoundSource source) async {
    final player = _player ??= AudioPlayer();

    // 이전 미리듣기를 끊는다 — 두 소리가 겹치면 무엇을 고르는지 알 수 없다
    await player.stop();

    switch (source) {
      case AssetSound(:final assetPath):
        await player.setAsset(assetPath);
      case FileSound(:final filePath):
        await player.setFilePath(filePath);
    }

    // 한 번만 들려준다
    await player.setLoopMode(LoopMode.off);

    // 재생 완료를 기다리지 않는다 — 기다리면 목록이 멈춘 것처럼 보인다.
    // 실패는 삼킨다: 미리듣기가 안 되는 것이 화면을 죽일 이유는 없다.
    unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object {
      // 중단 실패를 삼킨다
    }
  }
}
