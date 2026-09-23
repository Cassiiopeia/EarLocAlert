import 'dart:async';

import 'package:ear_loc_alert/app/background/alert_watch_service.dart';
import 'package:ear_loc_alert/app/pending_alert_resumer.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 대기 알림 승격의 경합 (이슈 #142 QA)
///
/// 에뮬레이터에서 앱을 띄운 채 도착 알림을 받았더니 두 가지가 났다.
///
/// - `resumed` 와 폴링이 겹쳐 **같은 대기 알림을 두 번 꺼냈다** — 세션이
///   두 번 시작됐다 (복원 두 줄이 58ms 차이)
/// - 폴링이 "없음"을 읽고 네이티브 확인을 기다리는 사이 알림이 도착해,
///   **방금 울리기 시작한 알림을 고아로 오인해 꺼버렸다** — 진동이 끊겼다가
///   몇 초 뒤 다시 시작됐고, 알림 화면이 뜨기까지 15초가 걸린 적도 있다
void main() {
  final request = AlertRequest(
    placeId: 'p1',
    placeName: '독서실',
    direction: AlertDirection.enter,
    soundEnabled: true,
    occurredAt: DateTime.utc(2026, 9, 23),
  );

  late _FakeWatch watch;
  late List<AlertRequest> promoted;
  late int cancelled;

  setUp(() {
    watch = _FakeWatch();
    promoted = [];
    cancelled = 0;
  });

  PendingAlertResumer resumer({
    required Future<({AlertRequest? request, bool hadPending})> Function() take,
    Future<bool> Function()? hasPending,
  }) => PendingAlertResumer(
    takeRequest: take,
    hasPending: hasPending ?? () async => false,
    watch: watch,
    cancelNotification: () async => cancelled++,
    promote: (r) async => promoted.add(r),
  );

  group('겹쳐 부르면 한 번만 돈다', () {
    test('resumed 와 폴링이 동시에 들어와도 세션은 하나다', () async {
      // 첫 호출이 꺼내는 도중에 두 번째가 들어오는 상황을 만든다
      final gate = Completer<void>();
      var takes = 0;
      var stored = true;
      final target = resumer(
        take: () async {
          takes++;
          await gate.future;
          if (!stored) return (request: null, hadPending: false);
          stored = false;
          return (request: request, hadPending: true);
        },
      );

      final first = target.resume(trigger: 'resumed');
      final second = target.resume(trigger: '폴링');
      gate.complete();
      await Future.wait([first, second]);

      expect(takes, 1, reason: '두 번째 호출은 진행 중인 것을 기다려야 한다');
      expect(promoted, hasLength(1));
    });

    test('끝난 뒤에 부르면 다시 돈다 — 다음 알림을 놓치면 안 된다', () async {
      var takes = 0;
      final target = resumer(
        take: () async {
          takes++;
          return (request: null, hadPending: false);
        },
      );

      await target.resume(trigger: '폴링');
      await target.resume(trigger: '폴링');

      expect(takes, 2);
    });
  });

  group('세션 없이 울리는 알림 (#130)', () {
    test('확인하는 사이 방금 도착한 알림은 끄지 않고 바로 승격한다', () async {
      // 첫 take 는 저장 전이라 "없음". 네이티브를 확인하는 동안 저장·진동이
      // 시작된다 — 네이티브는 저장한 다음에 울린다
      var stored = false;
      var takes = 0;
      watch.onIsAlerting = () => stored = true;
      watch.alerting = true;

      final target = resumer(
        take: () async {
          takes++;
          if (!stored) return (request: null, hadPending: false);
          stored = false;
          return (request: request, hadPending: true);
        },
        hasPending: () async => stored,
      );

      await target.resume(trigger: '폴링');

      expect(
        watch.stops,
        1,
        reason: '승격 직전 한 번만 끊는다 — 고아 정리로 먼저 끊으면 진동이 끊겼다 다시 운다',
      );
      expect(promoted, [request], reason: '다음 폴링을 기다리지 않고 그 자리에서 승격한다');
      expect(takes, 2);
    });

    test('정말 고아면 정리한다 — 앱이 죽었다 살아난 경우', () async {
      watch.alerting = true;
      final target = resumer(
        take: () async => (request: null, hadPending: false),
        hasPending: () async => false,
      );

      await target.resume(trigger: '시작');

      expect(watch.stops, 1);
      expect(cancelled, 1);
      expect(promoted, isEmpty);
    });

    test('울리지 않으면 아무것도 하지 않는다', () async {
      watch.alerting = false;
      final target = resumer(
        take: () async => (request: null, hadPending: false),
      );

      await target.resume(trigger: '폴링');

      expect(watch.stops, 0);
      expect(cancelled, 0);
    });

    test('다시 꺼내도 비어 있으면 한 번만 더 시도하고 멈춘다', () async {
      // hasPending 은 참인데 take 는 계속 빈 값 — 값이 깨진 경우 등.
      // 무한히 돌면 폴링마다 쌓인다
      watch.alerting = true;
      var takes = 0;
      final target = resumer(
        take: () async {
          takes++;
          return (request: null, hadPending: false);
        },
        hasPending: () async => true,
      );

      await target.resume(trigger: '폴링');

      expect(takes, 2);
      expect(watch.stops, 0, reason: '짝이 있다고 나온 이상 끄지 않는다');
    });
  });

  test('만료된 알림도 네이티브는 끊는다 (#83)', () async {
    final target = resumer(take: () async => (request: null, hadPending: true));

    await target.resume(trigger: '시작');

    expect(watch.stops, 1);
    expect(cancelled, 1);
    expect(promoted, isEmpty);
  });
}

class _FakeWatch implements AlertWatchService {
  bool alerting = false;
  int stops = 0;
  void Function()? onIsAlerting;

  @override
  Future<bool> isAlerting() async {
    onIsAlerting?.call();
    return alerting;
  }

  @override
  Future<void> stopNativeAlert() async => stops++;

  @override
  Future<void> startWatching() async {}

  @override
  Future<void> stopWatching() async {}

  @override
  Future<void> syncGeofences(List<Map<String, Object?>> geofences) async {}
}
