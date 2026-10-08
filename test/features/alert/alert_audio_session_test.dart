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

  group('화면 없이 시작하는 iOS 세션 (이슈 #233)', () {
    final background =
        AlertSoundServiceImpl.alertSessionConfigurationBackground;

    test('다른 앱과 섞는다 — 백그라운드에서는 끊는 세션을 켤 수 없다', () {
      expect(
        background.avAudioSessionCategory,
        AVAudioSessionCategory.playback,
      );
      expect(
        background.avAudioSessionCategoryOptions,
        AVAudioSessionCategoryOptions.duckOthers,
        reason:
            '옵션이 없으면 활성화가 CannotInterruptOthers 로 실패해 이어폰이 '
            '있어도 진동으로만 떨어진다',
      );
    });

    test('Android 값은 전면 설정과 같다 — 스피커로 새는 용도를 쓰지 않는다', () {
      expect(background.androidAudioAttributes?.usage, AndroidAudioUsage.media);
      expect(background.androidWillPauseWhenDucked, isFalse);
      expect(
        background.androidAudioFocusGainType,
        AndroidAudioFocusGainType.gainTransient,
      );
    });
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
