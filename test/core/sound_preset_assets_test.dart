import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 프리셋 음원 파일이 실제로 존재하는가 (이슈 #121)
///
/// **enum 에 있는데 파일이 없으면 그 프리셋을 고른 사용자의 알림이 조용해진다.**
/// 재생 실패는 진동 폴백으로 이어지고, 사용자는 자기가 고른 소리가 왜
/// 안 나는지 알 방법이 없다.
///
/// `pubspec.yaml` 의 `assets:` 등록을 빠뜨리는 것이 가장 흔한 사고 경로다 —
/// 파일은 있는데 번들에 안 들어간다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('모든 프리셋의 음원이 번들에 들어 있다', () async {
    for (final preset in SoundPreset.values) {
      final data = await rootBundle.load(preset.assetPath);

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: '${preset.id} 의 음원이 비어 있다 (${preset.assetPath})',
      );
    }
  });

  test('음원이 WAV 형식이다', () async {
    for (final preset in SoundPreset.values) {
      final data = await rootBundle.load(preset.assetPath);
      final header = data.buffer.asUint8List(0, 12);

      expect(
        String.fromCharCodes(header.sublist(0, 4)),
        'RIFF',
        reason: '${preset.id} 가 WAV 가 아니다 — 확장자만 바꾼 파일일 수 있다',
      );
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
    }
  });

  test('음원이 지나치게 크지 않다', () async {
    for (final preset in SoundPreset.values) {
      final data = await rootBundle.load(preset.assetPath);

      expect(
        data.lengthInBytes,
        lessThan(512 * 1024),
        reason:
            '${preset.id} 가 512KB 를 넘는다 — 내장 음원이 늘어날수록 '
            '앱 크기가 그만큼 커진다',
      );
    }
  });
}
