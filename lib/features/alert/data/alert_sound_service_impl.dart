import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/alert_effects.dart';

/// 알림음 재생 구현 (docs/10-DECISIONS.md 007)
///
/// **이 클래스의 목적은 소리를 내는 것이 아니라 스피커로 새지 않게 하는 것이다.**
///
/// 두 OS 모두 블루투스 오디오 출력이 연결되어 있으면 미디어가 자동으로
/// 그리로 간다. 앱이 라우팅을 조작할 필요가 없다 — 해야 할 일은 반대로,
/// **연결되어 있지 않으면 재생하지 않는 것**이다.
class AlertSoundServiceImpl implements AlertSoundService {
  AlertSoundServiceImpl({String? assetPath})
    : _assetPath = assetPath ?? 'assets/sounds/alert.mp3';

  final String _assetPath;
  AudioPlayer? _player;

  @override
  Future<bool> isBluetoothConnected() async {
    final session = await AudioSession.instance;
    final devices = await session.getDevices(includeInputs: false);

    return devices.any(
      (device) =>
          device.type == AudioDeviceType.bluetoothA2dp ||
          device.type == AudioDeviceType.bluetoothSco ||
          device.type == AudioDeviceType.bluetoothLe,
    );
  }

  @override
  Future<void> play() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);

      final player = _player ??= AudioPlayer();
      await player.setAsset(_assetPath);
      await player.play();
    } on Object catch (error) {
      // 호출자는 이 예외를 받아 재시도 없이 진동으로 떨어진다
      throw AlertSoundException('$error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object {
      // 중단 실패를 삼킨다 — 해제는 항상 완료되어야 한다
    }
  }
}
