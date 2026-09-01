import 'package:just_audio/just_audio.dart';

import '../domain/sound_probe.dart';

/// `just_audio` 로 실제 로드를 시도한다 (이슈 #121)
///
/// **확장자를 믿지 않는 것이 이 클래스의 존재 이유다.** `.mp3` 로 이름만
/// 바꾼 파일은 등록 시점에는 멀쩡해 보이다가, 정작 알림이 울려야 하는
/// 순간에 재생이 실패해 진동만 남는다. 그 실패를 여기서 미리 겪는다.
class JustAudioSoundProbe implements SoundProbe {
  const JustAudioSoundProbe();

  @override
  Future<Duration?> probe(String filePath) async {
    // 알림용 플레이어와 섞지 않는다 — 검사 도중 알림이 울리면
    // 그쪽 재생이 끊긴다
    final player = AudioPlayer();
    try {
      // setFilePath 는 로딩이 끝나면 길이를 돌려준다.
      // 디코딩할 수 없으면 여기서 예외가 난다.
      return await player.setFilePath(filePath);
    } on Object {
      // 디코딩 실패는 정상적인 결과 중 하나다 — 던지지 않는다
      return null;
    } finally {
      await player.dispose();
    }
  }
}
