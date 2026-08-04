import 'package:audio_session/audio_session.dart';
import 'package:ear_loc_alert/features/alert/data/alert_sound_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// 어떤 출력 장치를 "본인만 듣는 출력"으로 볼 것인가 (docs/10-DECISIONS.md 018).
///
/// 이 목록이 이 앱의 핵심 가치를 직접 결정한다. 좁으면 이어폰을 꽂고도
/// 소리가 안 나고, 넓으면 주변에 소리가 샌다.
void main() {
  const types = AlertSoundServiceImpl.headphoneTypes;

  group('이어폰 판정 목록', () {
    test('줄이어폰이 포함된다 — 블루투스만 보던 회귀를 막는다', () {
      expect(types, contains(AudioDeviceType.wiredHeadset));
      expect(types, contains(AudioDeviceType.wiredHeadphones));
    });

    test('USB-C 이어폰이 포함된다 — 3.5mm 잭 없는 기기의 유일한 유선 경로', () {
      expect(types, contains(AudioDeviceType.usbAudio));
    });

    test('블루투스 프로파일 세 가지가 모두 포함된다', () {
      expect(types, contains(AudioDeviceType.bluetoothA2dp));
      expect(types, contains(AudioDeviceType.bluetoothSco));
      expect(types, contains(AudioDeviceType.bluetoothLe));
    });

    test('소리가 샐 수 있는 출력은 제외된다 (F3.7)', () {
      // 스피커는 물론이고, 차량 오디오·AirPlay·HDMI·독·라인아웃도
      // 주변에 들릴 수 있으므로 "이어폰"으로 보지 않는다.
      const leaky = [
        AudioDeviceType.builtInSpeaker,
        AudioDeviceType.builtInSpeakerSafe,
        AudioDeviceType.builtInEarpiece,
        AudioDeviceType.carAudio,
        AudioDeviceType.airPlay,
        AudioDeviceType.hdmi,
        AudioDeviceType.hdmiArc,
        AudioDeviceType.dock,
        AudioDeviceType.lineAnalog,
        AudioDeviceType.lineDigital,
        AudioDeviceType.auxLine,
        AudioDeviceType.unknown,
      ];
      for (final type in leaky) {
        expect(types, isNot(contains(type)), reason: '$type 은 소리가 샐 수 있다');
      }
    });

    test('허용 목록 방식이다 — 모르는 장치는 자동으로 제외된다', () {
      // 새 장치 종류가 생겨도 목록에 넣기 전까지는 소리가 나지 않는다.
      // 안 들리는 쪽으로 틀리는 것이 새는 쪽으로 틀리는 것보다 낫다.
      final excluded = AudioDeviceType.values.toSet().difference(types);
      expect(excluded, isNotEmpty);
      expect(types.length, lessThan(AudioDeviceType.values.length));
    });
  });
}
