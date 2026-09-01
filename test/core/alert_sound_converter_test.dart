import 'package:ear_loc_alert/core/database/alert_sound_converter.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 컬럼 왕복 (이슈 #121)
///
/// **`fromSql` 은 절대 던지면 안 된다.** 저장된 문자열 하나가 깨졌다고
/// 예외가 나면 장소를 통째로 못 읽고, 그러면 알림이 전부 멎는다.
/// `AlertScheduleListConverter` 가 같은 규약을 지킨다.
void main() {
  const converter = AlertSoundConverter();

  group('왕복', () {
    test('프리셋이 그대로 돌아온다', () {
      const sound = PresetSound(SoundPreset.defaultTone);
      expect(converter.fromSql(converter.toSql(sound)), sound);
    });

    test('커스텀 음원이 그대로 돌아온다', () {
      const sound = CustomSoundRef('0198-abcd');
      expect(converter.fromSql(converter.toSql(sound)), sound);
    });

    test('저장 문자열이 컬럼 기본값과 일치한다', () {
      expect(
        converter.toSql(AlertSound.fallback),
        'preset:default',
        reason:
            'tables.dart 의 withDefault 와 어긋나면 마이그레이션된 장소가 '
            '기본음이 아닌 것을 가리킨다',
      );
    });
  });

  group('깨진 값을 삼킨다', () {
    test('빈 문자열', () {
      expect(converter.fromSql(''), AlertSound.fallback);
    });

    test('구분자가 없는 값', () {
      expect(converter.fromSql('nonsense'), AlertSound.fallback);
    });

    test('모르는 종류', () {
      expect(converter.fromSql('http:whatever'), AlertSound.fallback);
    });

    test('사라진 프리셋 id', () {
      expect(
        converter.fromSql('preset:removed-in-newer-version'),
        AlertSound.fallback,
        reason: '앱을 이전 버전으로 되돌려 설치하면 실제로 일어난다',
      );
    });
  });
}
