import 'package:audio_session/audio_session.dart';
import 'package:ear_loc_alert/features/alert/data/alert_sound_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 오디오 세션 설정 (이슈 #129)
///
/// **넷플릭스를 보던 중 알림이 0.5초만 들리고 사라졌다.**
/// `AudioSessionConfiguration.speech()` 가 `willPauseWhenDucked: true` 라서,
/// 다른 앱이 우리를 duck 시키자 우리 재생이 멈춘 것이다.
///
/// 오디오 포커스 자체는 실기기에서만 확인되지만, **설정 값이 되돌아가는
/// 것은 여기서 막을 수 있다.** 이 파일이 그 역할이다.
void main() {
  final session = AlertSoundServiceImpl.alertSessionConfiguration;

  test('ducked 되어도 멈추지 않는다', () {
    expect(
      session.androidWillPauseWhenDucked,
      isFalse,
      reason:
          'true 면 다른 앱이 소리를 낼 때 알림이 잠깐 들리다 멈춘다 — '
          '사용자가 내릴 정거장을 놓친다',
    );
  });

  test('알람 용도로 선언하지 않는다 — 스피커로 샌다', () {
    expect(
      session.androidAudioAttributes?.usage,
      AndroidAudioUsage.media,
      reason:
          'alarm 은 이어폰이 연결돼 있어도 스피커로 함께 내보내는 '
          '기기가 있다. 이 앱에서 그것은 존재 이유를 잃는 사고다 '
          '(CLAUDE.md 금지 2). 다른 앱을 멈추는 것은 포커스 타입이 한다',
    );
  });

  test('알림음이지 음성이 아니다', () {
    expect(
      session.androidAudioAttributes?.contentType,
      AndroidAudioContentType.sonification,
    );
  });

  test('해제하면 원래 앱이 재개되는 포커스를 쓴다', () {
    expect(
      session.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gainTransient,
      reason: 'gain 은 영구 점유라 알림을 꺼도 넷플릭스가 재개되지 않는다',
    );
  });

  test('iOS 는 다른 앱을 중단시킨다', () {
    expect(session.avAudioSessionCategory, AVAudioSessionCategory.playback);
    expect(
      session.avAudioSessionCategoryOptions?.value ?? 0,
      0,
      reason: 'mixWithOthers·duckOthers 를 주면 다른 앱이 계속 재생된다',
    );
  });

  test('speech 프리셋을 쓰지 않는다', () {
    const speech = AudioSessionConfiguration.speech();

    expect(
      session.androidWillPauseWhenDucked,
      isNot(speech.androidWillPauseWhenDucked),
      reason: '이 차이가 이슈 #129 의 핵심이다',
    );
  });
}
