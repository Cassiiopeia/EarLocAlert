import 'dart:async';

import 'package:ear_loc_alert/app/arrival_alarm_coordinator.dart';
import 'package:ear_loc_alert/app/background/arrival_alarm_channel.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 잠금 화면 무음 알람과 알림 세션의 맞물림 (이슈 #235)
///
/// 알람은 화면만 덮는다. 세션과 따로 놀면 두 가지가 깨진다 — 알람을 껐는데
/// 진동이 계속되거나, 세션을 껐는데 잠금 화면에 알람이 남는다.
void main() {
  late _RecordingLogger logger;
  late _FakeAlarmPlatform platform;
  late bool ringing;
  late int dismissals;

  setUp(() {
    Diagnostics.resetForTest();
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    platform = _FakeAlarmPlatform();
    ringing = true;
    dismissals = 0;
  });

  tearDown(Diagnostics.resetForTest);

  ArrivalAlarmCoordinator coordinator() {
    final c = ArrivalAlarmCoordinator(
      platform: platform,
      isRinging: () => ringing,
      dismissSession: () async {
        dismissals++;
        ringing = false;
      },
    );
    c.attach();
    return c;
  }

  Future<void> present(ArrivalAlarmCoordinator c) => c.present(
    placeName: '강남역',
    title: '강남역 · 도착',
    stopLabel: '알림 끄기',
    openLabel: '앱 열기',
  );

  test('허용돼 있으면 장소 이름과 끄기 문구로 알람을 띄운다', () async {
    final c = coordinator();

    await present(c);

    expect(platform.presented, [('강남역 · 도착', '알림 끄기', '앱 열기')]);
    expect(c.presentedId, 'alarm-1');
    expect(logger.lines, contains('[alarm] presenting place=강남역'));
    expect(logger.lines, contains('[alarm] presented place=강남역 id=alarm-1'));
  });

  test('iOS 26 미만이면 띄우지 않고 사유를 남긴다', () async {
    platform.status_ = ArrivalAlarmStatus.unsupported;
    final c = coordinator();

    await present(c);

    expect(platform.presented, isEmpty);
    expect(
      logger.lines,
      contains('[alarm] skipped place=강남역 reason=unsupported'),
    );
  });

  test('허용되지 않았으면 띄우지 않고 권한 상태를 남긴다', () async {
    platform.status_ = const ArrivalAlarmStatus(
      supported: true,
      authorization: ArrivalAlarmAuthorization.denied,
    );
    final c = coordinator();

    await present(c);

    expect(platform.presented, isEmpty);
    expect(
      logger.lines,
      contains('[alarm] skipped place=강남역 reason=not_authorized auth=denied'),
    );
  });

  test('띄우기가 실패해도 던지지 않고 사유를 남긴다', () async {
    platform.failPresent = true;
    final c = coordinator();

    await present(c);

    expect(c.presentedId, isNull);
    expect(logger.lines.any((l) => l.contains('reason=failed')), isTrue);
  });

  test('세션이 끝나면 알람도 끈다', () async {
    final c = coordinator();
    await present(c);

    await c.onSessionEnded();

    expect(platform.stops, ['dismissed']);
    expect(c.presentedId, isNull);
  });

  test('앱이 전면으로 오면 알람을 끈다 — 알림 화면과 겹치지 않게', () async {
    final c = coordinator();
    await present(c);

    await c.onForeground();

    expect(platform.stops, ['foreground']);
    // 세션은 그대로 — 앱 화면이 이어서 울린다
    expect(dismissals, 0);
  });

  test('띄운 알람이 없으면 끄지 않는다', () async {
    final c = coordinator();

    await c.onSessionEnded();
    await c.onForeground();

    expect(platform.stops, isEmpty);
  });

  test('사용자가 잠금 화면에서 알람을 끄면 세션도 끈다', () async {
    final c = coordinator();
    await present(c);

    await platform.userStops('alarm-1');

    expect(dismissals, 1);
    expect(c.presentedId, isNull);
    expect(
      logger.lines,
      contains('[alarm] stopped by user id=alarm-1, dismissing session'),
    );
  });

  test('우리가 먼저 끈 알람의 꺼짐 신호로 세션을 다시 끄지 않는다', () async {
    final c = coordinator();
    await present(c);
    await c.onSessionEnded();

    await platform.userStops('alarm-1');

    expect(dismissals, 0);
  });

  test('세션이 이미 끝났으면 꺼짐 신호에 아무것도 끄지 않는다', () async {
    final c = coordinator();
    await present(c);
    ringing = false;

    await platform.userStops('alarm-1');

    expect(dismissals, 0);
  });

  test('띄우는 사이 해제되면 다 띄운 뒤 바로 끈다', () async {
    final gate = Completer<void>();
    platform.presentGate = gate;
    final c = coordinator();

    final pending = present(c);
    await Future<void>.delayed(Duration.zero);
    ringing = false;
    await c.onSessionEnded();
    gate.complete();
    await pending;

    expect(platform.stops, ['session_ended']);
    expect(c.presentedId, isNull);
  });

  test('아직 묻지 않았을 때만 권한을 묻는다', () async {
    platform.status_ = const ArrivalAlarmStatus(
      supported: true,
      authorization: ArrivalAlarmAuthorization.notDetermined,
    );
    final c = coordinator();

    final result = await c.requestIfUndetermined('onboarding_finished');

    expect(result, ArrivalAlarmAuthorization.authorized);
    expect(platform.authRequests, 1);
    expect(
      logger.lines,
      contains(
        '[alarm] authorization requested trigger=onboarding_finished '
        'result=authorized',
      ),
    );

    platform.status_ = const ArrivalAlarmStatus(
      supported: true,
      authorization: ArrivalAlarmAuthorization.denied,
    );
    expect(await c.requestIfUndetermined('start'), isNull);
    expect(platform.authRequests, 1);
  });

  test('지원하지 않으면 권한을 묻지 않는다', () async {
    platform.status_ = ArrivalAlarmStatus.unsupported;
    final c = coordinator();

    expect(await c.requestIfUndetermined('start'), isNull);
    expect(platform.authRequests, 0);
  });
}

class _FakeAlarmPlatform implements ArrivalAlarmPlatform {
  ArrivalAlarmStatus status_ = const ArrivalAlarmStatus(
    supported: true,
    authorization: ArrivalAlarmAuthorization.authorized,
  );
  bool failPresent = false;
  Completer<void>? presentGate;
  final presented = <(String, String, String)>[];
  final stops = <String>[];
  int authRequests = 0;
  Future<void> Function(String id)? _onStopped;

  Future<void> userStops(String id) => _onStopped!(id);

  @override
  Future<ArrivalAlarmStatus> status() async => status_;

  @override
  Future<ArrivalAlarmAuthorization> requestAuthorization() async {
    authRequests++;
    return ArrivalAlarmAuthorization.authorized;
  }

  @override
  Future<String> present({
    required String title,
    required String stopLabel,
    required String openLabel,
  }) async {
    if (presentGate != null) await presentGate!.future;
    if (failPresent) throw StateError('schedule_failed');
    presented.add((title, stopLabel, openLabel));
    return 'alarm-${presented.length}';
  }

  @override
  Future<void> stopAll(String reason) async => stops.add(reason);

  @override
  Future<void> openSettings() async {}

  @override
  void setStopHandler(Future<void> Function(String id) onStopped) =>
      _onStopped = onStopped;
}

class _RecordingLogger implements DiagnosticLogger {
  final List<String> lines = [];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}
