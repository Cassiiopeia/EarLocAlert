import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 식별자 파싱 (이슈 #121)
///
/// **이 파서는 절대 던지면 안 된다.** 저장된 문자열 하나가 깨졌다고
/// 알림이 멎으면, 사용자는 왜 소리가 안 나는지 영영 모른다. 모르는 값은
/// 전부 기본음으로 흡수된다.
void main() {
  group('SoundPreset.fromId', () {
    test('아는 id 는 그 프리셋이다', () {
      expect(SoundPreset.fromId('default'), SoundPreset.defaultTone);
    });

    test('모르는 id 는 기본음이다', () {
      expect(
        SoundPreset.fromId('does-not-exist'),
        SoundPreset.defaultTone,
        reason: '앱을 이전 버전으로 되돌리면 아직 없는 프리셋을 가리킬 수 있다',
      );
    });

    test('null 이어도 기본음이다', () {
      expect(SoundPreset.fromId(null), SoundPreset.defaultTone);
    });

    test('모든 프리셋의 id 가 서로 다르다', () {
      final ids = SoundPreset.values.map((p) => p.id).toSet();
      expect(
        ids.length,
        SoundPreset.values.length,
        reason: 'id 가 겹치면 fromId 가 엉뚱한 프리셋을 돌려준다',
      );
    });

    test('모든 프리셋이 assets 경로를 가진다', () {
      for (final preset in SoundPreset.values) {
        expect(preset.assetPath, startsWith('assets/sounds/'));
      }
    });
  });

  group('AlertSound.parse', () {
    test('프리셋을 읽는다', () {
      expect(
        AlertSound.parse('preset:default'),
        const PresetSound(SoundPreset.defaultTone),
      );
    });

    test('커스텀 음원을 읽는다', () {
      expect(
        AlertSound.parse('custom:abc-123'),
        const CustomSoundRef('abc-123'),
      );
    });

    test('모르는 프리셋 id 는 기본음으로 떨어진다', () {
      expect(AlertSound.parse('preset:nope'), AlertSound.fallback);
    });

    test('uuid 가 비어 있으면 기본음이다', () {
      expect(
        AlertSound.parse('custom:'),
        AlertSound.fallback,
        reason: '가리키는 파일이 없는 참조다',
      );
    });

    test('구분자가 없으면 기본음이다', () {
      expect(AlertSound.parse('garbage'), AlertSound.fallback);
    });

    test('종류가 비어 있으면 기본음이다', () {
      expect(AlertSound.parse(':default'), AlertSound.fallback);
    });

    test('빈 문자열이어도 던지지 않는다', () {
      expect(AlertSound.parse(''), AlertSound.fallback);
    });

    test('모르는 종류는 기본음이다', () {
      expect(
        AlertSound.parse('remote:https://example.com/a.mp3'),
        AlertSound.fallback,
      );
    });

    test('uuid 안의 콜론을 잘라내지 않는다', () {
      expect(
        AlertSound.parse('custom:a:b:c'),
        const CustomSoundRef('a:b:c'),
        reason: '첫 콜론만 구분자다 — 뒤쪽을 잘라내면 다른 파일을 가리킨다',
      );
    });
  });

  group('storageValue 왕복', () {
    test('프리셋이 그대로 돌아온다', () {
      for (final preset in SoundPreset.values) {
        final sound = PresetSound(preset);
        expect(AlertSound.parse(sound.storageValue), sound);
      }
    });

    test('커스텀 음원이 그대로 돌아온다', () {
      const sound = CustomSoundRef('9f8e-7d6c');
      expect(AlertSound.parse(sound.storageValue), sound);
    });

    test('기본값의 저장 문자열이 Drift 컬럼 기본값과 같다', () {
      expect(
        AlertSound.fallback.storageValue,
        'preset:default',
        reason:
            'tables.dart 의 withDefault 와 어긋나면 마이그레이션된 장소가 '
            '기본음이 아닌 것을 가리킨다',
      );
    });
  });
}
