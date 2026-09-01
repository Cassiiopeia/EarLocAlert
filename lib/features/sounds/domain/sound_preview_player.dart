import '../../../core/audio/alert_sound_source.dart';

/// 음원 미리듣기 (이슈 #121)
///
/// **알림 재생과 다른 플레이어를 쓴다.** 미리듣기 도중 알림이 울리면
/// 같은 플레이어를 공유했을 때 한쪽이 다른 쪽을 끊는다.
///
/// **반복하지 않는다** — 알림은 해제할 때까지 울려야 하지만 미리듣기는
/// 한 번 들으면 끝이다.
abstract interface class SoundPreviewPlayer {
  /// **호출 전에 이어폰 연결이 확인된 상태여야 한다.**
  /// 이 규칙은 알림과 똑같이 적용된다 — 도서관에서 스피커가 울리면
  /// 그것이 미리듣기였는지 알림이었는지는 중요하지 않다.
  Future<void> play(AlertSoundSource source);

  /// 화면을 닫을 때 반드시 부른다
  Future<void> stop();
}
