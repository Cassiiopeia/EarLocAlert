import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/audio_session_headphone_detector.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/audio/headphone_detector.dart';
import '../data/custom_sound_repository_provider.dart';
import '../data/file_picker_sound_source.dart';
import '../data/just_audio_preview_player.dart';
import '../data/just_audio_sound_probe.dart';
import '../domain/custom_sound.dart';
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

/// 사용자가 올린 음원 목록 (#278) — 추가·삭제 뒤 invalidate 해서 다시 읽는다
///
/// 예전에는 알림음 시트가 `setState` 로 들고 있었다(docs/04-CONVENTIONS —
/// 화면 데이터는 Riverpod). 못 읽어도 프리셋은 고를 수 있어야 해서 빈 목록이다.
@riverpod
Future<List<CustomSound>> customSoundList(Ref ref) async {
  try {
    return await ref.watch(customSoundRepositoryProvider).findAll();
  } on Object catch (error) {
    Diagnostics.log('sound', 'custom sound list read failed error=$error');
    return const [];
  }
}

/// 지금 이어폰이 연결돼 있는가 (#278) — 앱이 다시 앞으로 오면 invalidate 한다
///
/// 확인하지 못하면 연결되지 않은 것으로 본다 — 확인 못 한 상태로 재생하면
/// 스피커로 샐 수 있다 (CLAUDE.md 규칙 2).
@riverpod
Future<bool> headphoneConnection(Ref ref) async {
  try {
    return await ref.watch(headphoneDetectorProvider).isConnected();
  } on Object catch (error) {
    Diagnostics.log('sound', 'headphone check failed error=$error');
    return false;
  }
}
