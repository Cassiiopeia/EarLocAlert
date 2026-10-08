import 'dart:async';

import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background_alert_ringer.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_controller.dart';
import 'package:ear_loc_alert/features/alert/domain/audio_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면 없이 결정된 iOS 알림을 바로 울린다 (이슈 #233)
///
/// 실기기 v1.26.1: 23:49:22 에 도착이 정해지고 무음 햅틱 알림이 나갔는데, 세션
/// (이어폰 소리)은 사용자가 앱을 연 23:49:34 에야 시작했다. 이 파일은 세션이 그
/// 자리에서 시작하고, 반복 알림이 해제·화면 진입과 함께 멈추는지를 지킨다.
void main() {
  final alert = PendingAlert(
    placeId: 'p1',
    placeName: '테스트 위치',
    direction: AlertDirection.enter,
    soundEnabled: true,
    occurredAt: DateTime.utc(2026, 10, 8, 14, 49),
  );
  final request = AlertRequest(
    placeId: 'p1',
    placeName: '테스트 위치',
    direction: AlertDirection.enter,
    soundEnabled: true,
    occurredAt: DateTime.utc(2026, 10, 8, 14, 49),
  );

  late _RecordingLogger logger;
  late List<AlertRequest> started;
  late List<int> reminders;
  late int cleared;
  late bool ringing;
  late AudioRoute? route;
  late AlertRequest? pending;
  late bool startResult;

  setUp(() {
    Diagnostics.resetForTest();
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    started = [];
    reminders = [];
    cleared = 0;
    ringing = false;
    route = AudioRoute.silent;
    pending = request;
    startResult = true;
  });

  tearDown(Diagnostics.resetForTest);

  BackgroundAlertRinger ringer({
    Duration interval = const Duration(milliseconds: 20),
    int max = 3,
  }) => BackgroundAlertRinger(
    takeRequest: () async {
      // 한 번만 꺼낼 수 있다 — 저장소의 take 와 같다
      final value = pending;
      pending = null;
      return value;
    },
    startSession: (r) async {
      started.add(r);
      if (startResult) ringing = true;
      return startResult;
    },
    audioDecision: () async => route,
    remind: (_, n) async => reminders.add(n),
    clearNotifications: () async => cleared++,
    isRinging: () => ringing,
    reminderInterval: interval,
    maxReminders: max,
  );

  test('대기 알림을 꺼내 세션을 바로 시작하고 결과를 한 줄 남긴다', () async {
    final target = ringer();

    await target.ring(alert);

    expect(started.single.placeName, '테스트 위치');
    expect(target.isActive, isTrue);
    expect(
      logger.lines,
      contains(
        allOf(
          contains('[alert] background session started place=테스트 위치'),
          contains('audio=vibrate_only'),
        ),
      ),
    );
    await target.onSessionEnded();
  });

  test('이어폰으로 울렸으면 headphones 로 남긴다', () async {
    route = AudioRoute.headphones;
    final target = ringer();

    await target.ring(alert);

    expect(logger.lines, contains(contains('audio=headphones')));
    await target.onSessionEnded();
  });

  test('울리는 동안 반복 알림을 내고 상한에서 멈춘다', () async {
    final target = ringer(max: 3);

    await target.ring(alert);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(reminders, [1, 2, 3]);
    expect(
      logger.lines,
      contains(contains('background reminders stopped reason=limit sent=3')),
    );
    await target.onSessionEnded();
  });

  test('해제하면 반복을 멈추고 남은 알림을 지운다', () async {
    final target = ringer(max: 100);

    await target.ring(alert);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    ringing = false;
    await target.onSessionEnded();
    final sentAtDismiss = reminders.length;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(reminders, hasLength(sentAtDismiss), reason: '끈 뒤에 떨면 안 된다');
    expect(cleared, 1);
    expect(target.isActive, isFalse);
    expect(
      logger.lines,
      contains(contains('background reminders stopped reason=dismissed')),
    );
  });

  test('화면이 뜨면 반복을 멈춘다 — 알림 화면 위에 배너가 덮이지 않는다', () async {
    final target = ringer(max: 100);

    await target.ring(alert);
    await target.onForeground();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(reminders, isEmpty);
    expect(cleared, 1);
    expect(ringing, isTrue, reason: '세션은 그대로 울린다 — 사용자가 알림 화면에서 끈다');
  });

  test('승격 경로가 먼저 꺼냈으면 두 번째 세션을 만들지 않는다', () async {
    pending = null;
    final target = ringer();

    await target.ring(alert);

    expect(started, isEmpty);
    expect(target.isActive, isFalse);
    expect(
      logger.lines,
      contains(
        contains(
          'background session not started place=테스트 위치 reason=no_pending',
        ),
      ),
    );
  });

  test('이미 다른 알림이 울리면 반복을 새로 걸지 않는다', () async {
    startResult = false;
    final target = ringer(max: 100);

    await target.ring(alert);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(reminders, isEmpty);
    expect(logger.lines, contains(contains('reason=already_ringing')));
  });

  test('세션 시작이 실패해도 던지지 않고 사유를 남긴다', () async {
    final target = BackgroundAlertRinger(
      takeRequest: () async => request,
      startSession: (_) async => throw StateError('audio'),
      audioDecision: () async => null,
      remind: (_, _) async {},
      clearNotifications: () async {},
      isRinging: () => false,
    );

    await target.ring(alert);

    expect(logger.lines, contains(contains('reason=start_failed')));
  });

  test('오디오 판정이 늦어도 기다리지 않고 undecided 로 남긴다', () async {
    final never = Completer<AudioRoute?>();
    final target = BackgroundAlertRinger(
      takeRequest: () async => request,
      startSession: (_) async => true,
      audioDecision: () => never.future,
      remind: (_, _) async {},
      clearNotifications: () async {},
      isRinging: () => true,
      audioDecisionTimeout: const Duration(milliseconds: 10),
    );

    await target.ring(alert);

    expect(logger.lines, contains(contains('audio=undecided')));
    await target.onSessionEnded();
  });

  test('반복 알림을 내는 사이 해제되면 방금 낸 것도 지운다', () async {
    final posting = Completer<void>();
    final target = BackgroundAlertRinger(
      takeRequest: () async => request,
      startSession: (_) async => true,
      audioDecision: () async => AudioRoute.silent,
      remind: (_, _) => posting.future,
      clearNotifications: () async => cleared++,
      isRinging: () => true,
      reminderInterval: const Duration(milliseconds: 10),
    );

    await target.ring(alert);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await target.onSessionEnded();
    posting.complete();
    await Future<void>.delayed(Duration.zero);

    // 해제 때 한 번 + 내던 반복 알림마다 한 번 더
    expect(cleared, greaterThan(1));
  });
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
