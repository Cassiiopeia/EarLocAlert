import 'package:ear_loc_alert/features/sounds/domain/sound_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 사용자 음원 검증 (이슈 #121)
///
/// **상한을 두는 이유는 앱 용량이다.** 진단 로그도 같은 이유로 회전
/// 상한을 뒀다 (이슈 #106). 경계값에서 한 칸씩 어긋나면 상한이 의미를
/// 잃으므로 이하/초과를 정확히 못박는다.
void main() {
  group('extensionOf', () {
    test('확장자를 소문자로 뽑는다', () {
      expect(SoundValidator.extensionOf('ring.MP3'), 'mp3');
    });

    test('점이 여러 개면 마지막 것이 확장자다', () {
      expect(SoundValidator.extensionOf('my.alarm.sound.m4a'), 'm4a');
    });

    test('확장자가 없으면 빈 문자열이다', () {
      expect(SoundValidator.extensionOf('ringtone'), '');
    });

    test('점으로 끝나면 빈 문자열이다', () {
      expect(SoundValidator.extensionOf('ringtone.'), '');
    });

    test('숨김 파일의 점은 확장자가 아니다', () {
      expect(
        SoundValidator.extensionOf('.gitignore'),
        'gitignore',
        reason: '표시용 이름이라 숨김 파일이 올 일은 없지만 죽지는 않아야 한다',
      );
    });
  });

  group('baseNameOf', () {
    test('확장자를 뗀다', () {
      expect(SoundValidator.baseNameOf('알람소리.mp3'), '알람소리');
    });

    test('확장자가 없으면 그대로다', () {
      expect(SoundValidator.baseNameOf('알람소리'), '알람소리');
    });
  });

  group('checkBeforeProbe — 개수', () {
    test('상한 직전이면 통과한다', () {
      expect(
        SoundValidator.checkBeforeProbe(
          fileName: 'a.mp3',
          sizeBytes: 1000,
          currentCount: SoundLimits.maxCount - 1,
        ),
        isNull,
      );
    });

    test('상한에 닿으면 거부한다', () {
      final error = SoundValidator.checkBeforeProbe(
        fileName: 'a.mp3',
        sizeBytes: 1000,
        currentCount: SoundLimits.maxCount,
      );
      expect(error, isA<SoundLimitReached>());
    });

    test('개수를 가장 먼저 본다', () {
      final error = SoundValidator.checkBeforeProbe(
        fileName: 'a.exe',
        sizeBytes: SoundLimits.maxBytes + 1,
        currentCount: SoundLimits.maxCount,
      );
      expect(
        error,
        isA<SoundLimitReached>(),
        reason: '어차피 못 넣는데 형식·크기를 따지는 것은 사용자에게 혼란이다',
      );
    });
  });

  group('checkBeforeProbe — 형식', () {
    test('허용 형식은 통과한다', () {
      for (final ext in SoundLimits.allowedExtensions) {
        expect(
          SoundValidator.checkBeforeProbe(
            fileName: 'sound.$ext',
            sizeBytes: 1000,
            currentCount: 0,
          ),
          isNull,
          reason: '$ext 는 허용 목록에 있다',
        );
      }
    });

    test('대문자 확장자도 통과한다', () {
      expect(
        SoundValidator.checkBeforeProbe(
          fileName: 'sound.WAV',
          sizeBytes: 1000,
          currentCount: 0,
        ),
        isNull,
      );
    });

    test('모르는 형식은 거부하고 확장자를 알려준다', () {
      final error = SoundValidator.checkBeforeProbe(
        fileName: 'video.mp4',
        sizeBytes: 1000,
        currentCount: 0,
      );
      expect(error, isA<UnsupportedSoundFormat>());
      expect((error! as UnsupportedSoundFormat).extension, 'mp4');
    });

    test('확장자가 없으면 거부한다', () {
      expect(
        SoundValidator.checkBeforeProbe(
          fileName: 'noext',
          sizeBytes: 1000,
          currentCount: 0,
        ),
        isA<UnsupportedSoundFormat>(),
      );
    });
  });

  group('checkBeforeProbe — 크기', () {
    test('상한과 같으면 통과한다', () {
      expect(
        SoundValidator.checkBeforeProbe(
          fileName: 'a.mp3',
          sizeBytes: SoundLimits.maxBytes,
          currentCount: 0,
        ),
        isNull,
        reason: '초과만 거부한다 — 딱 맞는 파일을 막을 이유가 없다',
      );
    });

    test('1바이트만 넘어도 거부하고 실제 크기를 알려준다', () {
      final error = SoundValidator.checkBeforeProbe(
        fileName: 'a.mp3',
        sizeBytes: SoundLimits.maxBytes + 1,
        currentCount: 0,
      );
      expect(error, isA<SoundTooLarge>());
      expect(
        (error! as SoundTooLarge).bytes,
        SoundLimits.maxBytes + 1,
        reason: '화면이 "8.2MB / 최대 5MB" 를 보여주려면 실제 값이 필요하다',
      );
    });
  });

  group('checkProbeResult', () {
    test('디코딩 실패는 재생 불가다', () {
      expect(SoundValidator.checkProbeResult(null), isA<SoundNotPlayable>());
    });

    test('길이가 0 이면 재생 불가다', () {
      expect(
        SoundValidator.checkProbeResult(Duration.zero),
        isA<SoundNotPlayable>(),
        reason: '재생은 되지만 소리가 안 난다 — 등록해봐야 알림이 조용하다',
      );
    });

    test('상한과 같으면 통과한다', () {
      expect(SoundValidator.checkProbeResult(SoundLimits.maxDuration), isNull);
    });

    test('1밀리초만 넘어도 거부하고 실제 길이를 알려준다', () {
      final tooLong = SoundLimits.maxDuration + const Duration(milliseconds: 1);
      final error = SoundValidator.checkProbeResult(tooLong);
      expect(error, isA<SoundTooLong>());
      expect((error! as SoundTooLong).duration, tooLong);
    });

    test('짧은 음원은 통과한다', () {
      expect(
        SoundValidator.checkProbeResult(const Duration(milliseconds: 500)),
        isNull,
      );
    });
  });
}
