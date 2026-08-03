import 'dart:async';

import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_controller.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// 호출 기록을 남기는 가짜 진동 서비스
class FakeVibration implements VibrationService {
  int startCount = 0;
  int stopCount = 0;
  bool failOnStop = false;

  @override
  Future<void> startRepeating({required Duration interval}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (failOnStop) throw Exception('진동 중단 실패');
  }
}

class FakeSound implements AlertSoundService {
  FakeSound({this.connected = false});

  bool connected;
  bool failOnPlay = false;
  bool failOnCheck = false;
  int playCount = 0;
  int stopCount = 0;

  @override
  Future<bool> isBluetoothConnected() async {
    if (failOnCheck) throw Exception('연결 확인 실패');
    return connected;
  }

  @override
  Future<void> play() async {
    playCount++;
    if (failOnPlay) throw const AlertSoundException('재생 실패');
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class FakeNotifier implements AlertNotifier {
  int showCount = 0;
  int dismissCount = 0;

  @override
  Future<void> show({required String placeName, required String body}) async {
    showCount++;
  }

  @override
  Future<void> dismiss() async {
    dismissCount++;
  }
}

/// **영원히 끝나지 않는** 사운드 서비스.
///
/// docs/02-ARCHITECTURE.md 규칙 4를 강제하는 핵심 도구다 —
/// 이런 구현이 물려 있어도 해제가 즉시 완료되어야 한다.
class HangingSound implements AlertSoundService {
  final _never = Completer<void>();

  @override
  Future<bool> isBluetoothConnected() async => true;

  @override
  Future<void> play() => _never.future;

  @override
  Future<void> stop() async {}
}

AlertRequest makeRequest({
  String placeId = 'p1',
  String placeName = '도착지',
  AlertDirection direction = AlertDirection.enter,
  bool soundEnabled = true,
}) {
  return AlertRequest(
    placeId: placeId,
    placeName: placeName,
    direction: direction,
    soundEnabled: soundEnabled,
    occurredAt: DateTime.utc(2026, 8, 3, 12),
  );
}

void main() {
  late FakeVibration vibration;
  late FakeSound sound;
  late FakeNotifier notifier;
  late AlertController controller;

  const interval = Duration(seconds: 3);

  AlertController build({AlertSoundService? soundOverride}) {
    return AlertController(
      vibration: vibration,
      sound: soundOverride ?? sound,
      notifier: notifier,
      routeDecider: const AudioRouteDecider(),
    );
  }

  setUp(() {
    vibration = FakeVibration();
    sound = FakeSound();
    notifier = FakeNotifier();
    controller = build();
  });

  group('발화 (F3.1, F3.2)', () {
    test('진동과 알림이 함께 시작된다', () async {
      await controller.fire(makeRequest(), vibrationInterval: interval);

      expect(vibration.startCount, 1);
      expect(notifier.showCount, 1);
      expect(controller.current, isNotNull);
    });

    test('세션에 장소 정보가 담긴다', () async {
      final session = await controller.fire(
        makeRequest(placeName: '학원', direction: AlertDirection.exit),
        vibrationInterval: interval,
      );

      expect(session?.placeName, '학원');
      expect(session?.direction, AlertDirection.exit);
    });
  });

  group('오디오 경로 (F3.4~F3.7)', () {
    test('블루투스 연결 + 소리 허용 → 재생한다', () async {
      sound.connected = true;
      final session = await controller.fire(
        makeRequest(),
        vibrationInterval: interval,
      );

      expect(session?.audioRoute, AudioRoute.bluetooth);
      expect(sound.playCount, 1);
    });

    test('블루투스 미연결 → 재생하지 않는다 (스피커 유출 방지)', () async {
      sound.connected = false;
      final session = await controller.fire(
        makeRequest(),
        vibrationInterval: interval,
      );

      expect(session?.audioRoute, AudioRoute.silent);
      expect(sound.playCount, 0, reason: '연결 없이 play() 를 부르면 스피커로 샌다');
      expect(vibration.startCount, 1, reason: '진동은 여전히 동작해야 한다');
    });

    test('소리 설정이 꺼져 있으면 연결돼 있어도 재생하지 않는다', () async {
      sound.connected = true;
      final session = await controller.fire(
        makeRequest(soundEnabled: false),
        vibrationInterval: interval,
      );

      expect(session?.audioRoute, AudioRoute.silent);
      expect(sound.playCount, 0);
    });

    test('연결 확인이 실패하면 미연결로 간주한다', () async {
      sound.failOnCheck = true;
      final session = await controller.fire(
        makeRequest(),
        vibrationInterval: interval,
      );

      expect(
        session?.audioRoute,
        AudioRoute.silent,
        reason: '확인 못 한 상태로 재생하면 스피커로 샐 수 있다',
      );
      expect(sound.playCount, 0);
    });

    test('재생 실패 시 재시도하지 않고 진동으로 떨어진다', () async {
      sound.connected = true;
      sound.failOnPlay = true;
      final session = await controller.fire(
        makeRequest(),
        vibrationInterval: interval,
      );

      expect(session?.audioRoute, AudioRoute.silent);
      expect(sound.playCount, 1, reason: '재시도하면 라우팅이 바뀌어 스피커로 샐 수 있다');
    });
  });

  group('발화 중 재발화 차단 (docs/03-DOMAIN.md 규칙 4)', () {
    test('같은 장소의 이벤트는 무시한다', () async {
      await controller.fire(
        makeRequest(placeId: 'a'),
        vibrationInterval: interval,
      );
      final second = await controller.fire(
        makeRequest(placeId: 'a'),
        vibrationInterval: interval,
      );

      expect(second, isNull);
      expect(vibration.startCount, 1, reason: '두 번 울리면 안 된다');
      expect(controller.queuedCount, 0);
    });

    test('다른 장소는 대기열에 들어간다', () async {
      await controller.fire(
        makeRequest(placeId: 'a'),
        vibrationInterval: interval,
      );
      final second = await controller.fire(
        makeRequest(placeId: 'b'),
        vibrationInterval: interval,
      );

      expect(second, isNull);
      expect(controller.queuedCount, 1);
      expect(controller.current?.placeId, 'a', reason: '먼저 온 알림이 유지된다');
    });

    test('해제하면 대기 중이던 알림이 이어서 울린다', () async {
      await controller.fire(
        makeRequest(placeId: 'a'),
        vibrationInterval: interval,
      );
      await controller.fire(
        makeRequest(placeId: 'b'),
        vibrationInterval: interval,
      );

      await controller.dismiss(vibrationInterval: interval);

      expect(controller.current?.placeId, 'b');
      expect(controller.queuedCount, 0);
      expect(vibration.startCount, 2);
    });
  });

  group('해제 (F3.6, A-08)', () {
    test('진동·소리·알림이 모두 중단된다', () async {
      sound.connected = true;
      await controller.fire(makeRequest(), vibrationInterval: interval);

      await controller.dismiss();

      expect(vibration.stopCount, 1);
      expect(sound.stopCount, 1);
      expect(notifier.dismissCount, 1);
      expect(controller.current, isNull);
    });

    test('울리고 있지 않으면 null 을 반환하고 아무 일도 하지 않는다', () async {
      final result = await controller.dismiss();

      expect(result, isNull);
      expect(vibration.stopCount, 0);
    });

    test('진동 중단이 실패해도 세션은 정리되고 나머지도 중단된다', () async {
      vibration.failOnStop = true;
      await controller.fire(makeRequest(), vibrationInterval: interval);

      await controller.dismiss();

      expect(controller.current, isNull, reason: '세션이 남으면 다음 알림이 막힌다');
      expect(sound.stopCount, 1, reason: '하나가 실패해도 나머지는 중단한다');
      expect(notifier.dismissCount, 1);
    });
  });

  group('해제 즉시성 (docs/02-ARCHITECTURE.md 규칙 4)', () {
    test('오디오 재생이 영원히 끝나지 않아도 해제는 완료된다', () async {
      final hanging = HangingSound();
      controller = build(soundOverride: hanging);

      // 발화는 재생 대기로 완료되지 않는다 — await 하지 않는다
      unawaited(controller.fire(makeRequest(), vibrationInterval: interval));
      await Future<void>.delayed(Duration.zero);

      // 그래도 해제는 즉시 끝나야 한다
      final dismissed = await controller.dismiss().timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw StateError('해제가 지연되었다 — 규칙 4 위반'),
      );

      expect(vibration.stopCount, greaterThan(0));
      expect(controller.current, isNull, reason: '재생 대기와 무관하게 세션이 정리되어야 한다');
      expect(dismissed, anyOf(isNull, isNotNull));
    });

    test('진동은 소리 판정보다 먼저 시작된다', () async {
      final hanging = HangingSound();
      controller = build(soundOverride: hanging);

      unawaited(controller.fire(makeRequest(), vibrationInterval: interval));
      await Future<void>.delayed(Duration.zero);

      expect(vibration.startCount, 1, reason: '소리 판정이 오래 걸려도 진동은 이미 전달되어야 한다');
    });
  });
}
