import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/alert_effects.dart';

/// 알림음 재생 구현 (docs/10-DECISIONS.md 007·018)
///
/// **이 클래스의 목적은 소리를 내는 것이 아니라 스피커로 새지 않게 하는 것이다.**
///
/// 두 OS 모두 이어폰이 연결되어 있으면 미디어가 자동으로 그리로 간다.
/// 앱이 라우팅을 조작할 필요가 없다 — 해야 할 일은 반대로,
/// **연결되어 있지 않으면 재생하지 않는 것**이다.
class AlertSoundServiceImpl implements AlertSoundService {
  AlertSoundServiceImpl({String? assetPath})
    : _assetPath = assetPath ?? 'assets/sounds/alert.wav';

  /// 본인 귀로만 들어가는 출력.
  ///
  /// **허용 목록이다 — 모르는 장치는 제외된다.** 새 장치 종류가 생겼을 때
  /// 소리가 안 나는 쪽으로 틀리는 것이, 스피커로 새는 쪽으로 틀리는 것보다 낫다.
  ///
  /// 차량 오디오·AirPlay·HDMI·독·라인아웃은 주변에 들릴 수 있어 제외한다.
  /// 이것들은 "이어폰이 아니라서" 빠진 게 아니라 **소리가 새기 때문에** 빠졌다.
  @visibleForTesting
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

  final String _assetPath;
  AudioPlayer? _player;

  @override
  Future<bool> isHeadphoneConnected() async {
    final session = await AudioSession.instance;
    final devices = await session.getDevices(includeInputs: false);

    return devices.any((device) => headphoneTypes.contains(device.type));
  }

  @override
  Future<void> play({required double volume}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);

      final player = _player ??= AudioPlayer();
      // 사용자가 설정한 알림음 크기 (이슈 #86). 재생 시작 전에 걸어야
      // 첫 소리부터 그 크기다 — 큰 소리가 한 번 나가고 줄어드는 것은 늦다.
      await player.setVolume(volume.clamp(0.0, 1.0));
      // 음원 로딩까지는 기다린다 — 여기서 실패해야 진동으로 떨어질 수 있다
      await player.setAsset(_assetPath);
      // 해제할 때까지 반복한다. 진동이 반복되는 동안 소리만 한 번 나고
      // 마는 것은 알림으로서 약하다 — 졸다 깬 사용자가 놓친다.
      await player.setLoopMode(LoopMode.one);

      // **play() 를 기다리지 않는다.** 이 Future 는 재생이 *끝날 때* 완료되는데,
      // 반복 재생은 해제 전까지 끝나지 않는다. 기다리면 호출자가 영원히
      // 막혀 화면이 "이어폰으로 알림 중"으로 바뀌지 못한다.
      //
      // 다만 에러는 삼켜야 한다. 기다리지 않는 Future 가 실패하면 처리되지 않은
      // 비동기 예외가 되어 앱 전역으로 번진다. 여기서 실패해도 진동은
      // 이미 울리고 있고, 해제는 영향을 받지 않는다.
      unawaited(player.play().catchError((Object _) {}));
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
