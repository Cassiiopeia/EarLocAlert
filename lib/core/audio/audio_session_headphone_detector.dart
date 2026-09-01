import 'package:audio_session/audio_session.dart';
import 'headphone_detector.dart';

/// `audio_session` 으로 출력 장치를 확인한다 (docs/10-DECISIONS.md 018)
///
/// **허용 목록의 유일한 출처다.** 알림 발화와 음원 미리듣기가 같은 판정을
/// 써야 하는데, 목록이 두 곳에 복사되면 언젠가 어긋나고 그 방향이
/// "새 장치가 한쪽에만 추가됨" 이라 스피커로 새는 사고가 된다.
class AudioSessionHeadphoneDetector implements HeadphoneDetector {
  const AudioSessionHeadphoneDetector();

  /// 본인 귀로만 들어가는 출력.
  ///
  /// **허용 목록이다 — 모르는 장치는 제외된다.** 새 장치 종류가 생겼을 때
  /// 소리가 안 나는 쪽으로 틀리는 것이, 스피커로 새는 쪽으로 틀리는 것보다 낫다.
  ///
  /// 차량 오디오·AirPlay·HDMI·독·라인아웃은 주변에 들릴 수 있어 제외한다.
  /// 이것들은 "이어폰이 아니라서" 빠진 게 아니라 **소리가 새기 때문에** 빠졌다.
  static const headphoneTypes = <AudioDeviceType>{
    // 줄이어폰 — 3.5mm. 마이크 유무로 종류가 갈린다
    AudioDeviceType.wiredHeadset,
    AudioDeviceType.wiredHeadphones,
    // USB-C 이어폰. 3.5mm 잭이 없는 기기에서는 이쪽이 유일한 유선 경로다
    AudioDeviceType.usbAudio,
    // 블루투스
    AudioDeviceType.bluetoothA2dp,
    AudioDeviceType.bluetoothSco,
    AudioDeviceType.bluetoothLe,
    // 보청기 — 본인만 듣는다
    AudioDeviceType.hearingAid,
  };

  @override
  Future<bool> isConnected() async {
    final session = await AudioSession.instance;
    final devices = await session.getDevices(includeInputs: false);
    return devices.any((device) => headphoneTypes.contains(device.type));
  }
}
