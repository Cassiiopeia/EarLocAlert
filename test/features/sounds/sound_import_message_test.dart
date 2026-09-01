import 'package:ear_loc_alert/features/sounds/presentation/sound_import_message.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 등록 실패 문구 (이슈 #121)
///
/// **구체적인 숫자가 없으면 사용자는 무엇을 고쳐야 할지 모른다.**
/// "파일이 올바르지 않습니다" 로 뭉뚱그리면 파일을 바꿔야 하는지,
/// 지워야 하는지, 변환해야 하는지 알 수 없다.
void main() {
  group('formatBytes', () {
    test('MB 는 소수점 한 자리다', () {
      expect(formatBytes(8 * 1024 * 1024 + 200 * 1024), '8.2MB');
    });

    test('KB 는 반올림한다', () {
      expect(formatBytes(640 * 1024), '640KB');
    });

    test('작은 값은 바이트 그대로', () {
      expect(formatBytes(512), '512 B');
    });
  });

  group('formatDuration', () {
    test('1분 미만은 초 표기다', () {
      expect(formatDuration(const Duration(seconds: 3)), '0:03');
    });

    test('1분 이상은 분·초로 읽는다', () {
      expect(formatDuration(const Duration(seconds: 72)), '1분 12초');
    });
  });

  group('실패 문구', () {
    test('크기 초과는 실제 크기와 상한을 함께 보여준다', () {
      final message = soundImportErrorMessage(
        SoundTooLarge(8 * 1024 * 1024 + 200 * 1024),
      );

      expect(message, contains('8.2MB'));
      expect(message, contains('5.0MB'), reason: '상한을 모르면 얼마나 줄여야 하는지 알 수 없다');
    });

    test('길이 초과는 실제 길이와 상한을 함께 보여준다', () {
      final message = soundImportErrorMessage(
        const SoundTooLong(Duration(seconds: 72)),
      );

      expect(message, contains('1분 12초'));
      expect(message, contains('0:30'));
    });

    test('형식 오류는 쓸 수 있는 형식을 알려준다', () {
      final message = soundImportErrorMessage(
        const UnsupportedSoundFormat('mp4'),
      );

      expect(message, contains('mp4'));
      for (final ext in SoundLimits.allowedExtensions) {
        expect(message, contains(ext), reason: '무엇을 고를 수 있는지 알려주지 않으면 다시 실패한다');
      }
    });

    test('확장자가 없는 경우도 문구가 어색하지 않다', () {
      final message = soundImportErrorMessage(const UnsupportedSoundFormat(''));

      expect(message, contains('확장자가 없는'));
    });

    test('개수 초과는 상한과 해결 방법을 알려준다', () {
      final message = soundImportErrorMessage(const SoundLimitReached(10));

      expect(message, contains('${SoundLimits.maxCount}개'));
      expect(message, contains('지우고'));
    });

    test('재생 불가는 다른 파일을 권한다', () {
      expect(
        soundImportErrorMessage(const SoundNotPlayable()),
        contains('재생할 수 없는'),
      );
    });
  });
}
