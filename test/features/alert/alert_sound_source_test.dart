import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_controller.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_intensity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 장소별 알림음이 재생까지 전달되는가 (이슈 #121)
///
/// **판정은 그대로고 "무엇을 재생할지"만 바뀐다.** 이어폰이 없으면
/// 여전히 소리가 나지 않아야 하고, 그 규칙은 음원이 무엇이든 같다
/// (docs/03-DOMAIN.md 규칙 5).
class RecordingSound implements AlertSoundService {
  bool connected = true;
  int playCount = 0;
  AlertSoundSource? lastSource;

  @override
  Future<bool> isHeadphoneConnected() async => connected;

  @override
  Future<void> play({required double volume, AlertSoundSource? source}) async {
    playCount++;
    lastSource = source;
  }

  @override
  Future<void> stop() async {}
}

class NoopVibration implements VibrationService {
  @override
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  }) async {}

  @override
  Future<void> stop() async {}
}

class NoopNotifier implements AlertNotifier {
  @override
  Future<void> show({required String placeName, required String body}) async {}

  @override
  Future<void> dismiss() async {}
}

class FixedVolumeStore implements AlertVolumeStore {
  @override
  Future<double> volume() async => 0.5;

  @override
  Future<void> save(double volume) async {}
}

class NoopSystemVolume implements SystemVolumeService {
  @override
  Future<void> raiseTo(double fraction) async {}

  @override
  Future<void> restore() async {}
}

void main() {
  late RecordingSound sound;
  late AlertController controller;

  setUp(() {
    sound = RecordingSound();
    controller = AlertController(
      vibration: NoopVibration(),
      sound: sound,
      notifier: NoopNotifier(),
      routeDecider: const AudioRouteDecider(),
      volumeStore: FixedVolumeStore(),
      systemVolume: NoopSystemVolume(),
    );
  });

  tearDown(() => controller.dispose());

  /// 오디오 판정은 `unawaited` 로 돌아 프레임을 기다리지 않는다.
  /// 마이크로태스크를 몇 번 돌려 결과가 도착하게 한다 (기존 관례).
  Future<void> pumpAudio() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  AlertRequest request({AlertSoundSource? source, bool soundEnabled = true}) {
    return AlertRequest(
      placeId: 'p1',
      placeName: '도착지',
      direction: AlertDirection.enter,
      soundEnabled: soundEnabled,
      occurredAt: DateTime.utc(2026, 9, 1, 12),
      soundSource: source,
    );
  }

  test('지정한 asset 음원이 그대로 전달된다', () async {
    await controller.fire(
      request(source: const AssetSound('assets/sounds/bell.wav')),
      vibrationInterval: const Duration(seconds: 3),
    );
    await pumpAudio();

    expect(sound.playCount, 1);
    expect(
      (sound.lastSource! as AssetSound).assetPath,
      'assets/sounds/bell.wav',
    );
  });

  test('사용자 파일 음원이 그대로 전달된다', () async {
    await controller.fire(
      request(source: const FileSound('/data/sounds/u-1.mp3')),
      vibrationInterval: const Duration(seconds: 3),
    );
    await pumpAudio();

    expect((sound.lastSource! as FileSound).filePath, '/data/sounds/u-1.mp3');
  });

  test('음원을 싣지 않으면 null 이 전달된다 — 구현이 기본음을 쓴다', () async {
    await controller.fire(
      request(),
      vibrationInterval: const Duration(seconds: 3),
    );
    await pumpAudio();

    expect(sound.playCount, 1);
    expect(sound.lastSource, isNull);
  });

  test('이어폰이 없으면 음원을 지정해도 재생하지 않는다', () async {
    sound.connected = false;

    await controller.fire(
      request(source: const FileSound('/data/sounds/u-1.mp3')),
      vibrationInterval: const Duration(seconds: 3),
    );
    await pumpAudio();

    expect(
      sound.playCount,
      0,
      reason:
          '장소별 알림음은 "무엇을" 만 바꾼다. '
          '"재생할지 말지" 는 여전히 이어폰 판정이 정한다 (F3.7)',
    );
    expect(controller.current!.audioRoute, AudioRoute.silent);
  });

  test('장소가 소리를 껐으면 음원을 지정해도 재생하지 않는다', () async {
    await controller.fire(
      request(
        source: const FileSound('/data/sounds/u-1.mp3'),
        soundEnabled: false,
      ),
      vibrationInterval: const Duration(seconds: 3),
    );
    await pumpAudio();

    expect(sound.playCount, 0);
  });
}
