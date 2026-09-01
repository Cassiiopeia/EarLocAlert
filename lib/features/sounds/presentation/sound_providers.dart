// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/audio_session_headphone_detector.dart';
import '../../../core/audio/headphone_detector.dart';
import '../../../core/di/providers.dart';
import '../data/file_picker_sound_source.dart';
import '../data/just_audio_preview_player.dart';
import '../data/just_audio_sound_probe.dart';
import '../domain/sound_importer.dart';
import '../domain/sound_preview_player.dart';

part 'sound_providers.g.dart';

/// 알림음 관련 의존성 (이슈 #121)
///
/// 설정 저장소가 `alert` 에 있는 것과 같은 배치다 — 그 값을 소유한
/// feature 의 presentation 에 provider 를 둔다.

/// 이어폰 판정 — 미리듣기가 쓴다.
///
/// 알림 재생 쪽과 **같은 허용 목록**을 본다 (`core/audio`).
@Riverpod(keepAlive: true)
HeadphoneDetector headphoneDetector(Ref ref) =>
    const AudioSessionHeadphoneDetector();

@Riverpod(keepAlive: true)
SoundPreviewPlayer soundPreviewPlayer(Ref ref) {
  final player = JustAudioPreviewPlayer();
  // 화면이 사라져도 소리가 남지 않게 한다
  ref.onDispose(player.stop);
  return player;
}

@Riverpod(keepAlive: true)
SoundImporter soundImporter(Ref ref) => SoundImporter(
  picker: const FilePickerSoundSource(),
  probe: const JustAudioSoundProbe(),
  repository: ref.watch(customSoundRepositoryProvider),
);
