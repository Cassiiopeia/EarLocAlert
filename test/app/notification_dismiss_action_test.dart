import 'package:ear_loc_alert/app/background/notification_action_handler.dart';
import 'package:ear_loc_alert/app/notification_dismiss_action.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/core/platform/notification_actions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLogger implements DiagnosticLogger {
  final lines = <String>[];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}

NotificationResponse _response(String? actionId, {String? payload}) =>
    NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: actionId,
      payload: payload,
    );

/// 알림의 "알림 끄기" 버튼 (이슈 #237)
///
/// 잠금 화면에서 누른 사람은 진동이 멈추기를 바란다. 앱을 띄우거나 광고를
/// 보이면 안 되고(CLAUDE.md 규칙 1·3), 한 단계가 실패해도 나머지는 정리돼야 한다.
void main() {
  late _RecordingLogger logger;

  setUp(() {
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
  });
  tearDown(Diagnostics.resetForTest);

  group('앱 isolate 처리', () {
    NotificationDismissAction make(
      List<String> calls, {
      bool ringing = true,
      String? failing,
    }) {
      Future<void> Function() step(String name) => () async {
        calls.add(name);
        if (name == failing) throw StateError('boom');
      };
      return NotificationDismissAction(
        isRinging: () => ringing,
        dismissSession: step('dismiss'),
        stopReminders: step('reminders'),
        stopAlarms: step('alarms'),
        clearPending: step('pending'),
        clearNotifications: step('notifications'),
      );
    }

    test('세션을 먼저 끄고 반복 알림·알람·대기 알림·알림 순으로 정리한다', () async {
      final calls = <String>[];
      await make(calls).run(place: '회사');

      expect(calls, [
        'dismiss',
        'reminders',
        'alarms',
        'pending',
        'notifications',
      ]);
      expect(
        logger.lines,
        contains(
          '[notify] action tapped action=dismiss place=회사 handled=app session=ringing',
        ),
      );
    });

    test('세션이 없으면 끌 세션 없이 남은 흔적만 치운다', () async {
      final calls = <String>[];
      await make(calls, ringing: false).run(place: '회사');

      expect(calls, ['reminders', 'alarms', 'pending', 'notifications']);
    });

    test('한 단계가 실패해도 나머지를 계속하고 사유를 남긴다', () async {
      final calls = <String>[];
      await make(calls, failing: 'dismiss').run(place: '회사');

      expect(calls, [
        'dismiss',
        'reminders',
        'alarms',
        'pending',
        'notifications',
      ]);
      expect(
        logger.lines.any(
          (line) => line.contains('action step failed step=dismiss_session'),
        ),
        isTrue,
      );
    });
  });

  group('헤드리스 엔진 처리', () {
    test('앱 isolate 가 받으면 여기서는 정리하지 않는다', () async {
      final calls = <String>[];
      await handleNotificationActionInBackground(
        _response(NotificationActions.dismiss, payload: '회사'),
        relay: (place) async {
          calls.add('relay:$place');
          return true;
        },
        clearPending: () async => calls.add('pending'),
        clearNotifications: () async => calls.add('notifications'),
      );

      expect(calls, ['relay:회사']);
    });

    test('앱 isolate 가 없으면 대기 알림과 알림을 치우고 그렇게 남긴다', () async {
      final calls = <String>[];
      await handleNotificationActionInBackground(
        _response(NotificationActions.dismiss, payload: '회사'),
        relay: (_) async => false,
        clearPending: () async => calls.add('pending'),
        clearNotifications: () async => calls.add('notifications'),
      );

      expect(calls, ['pending', 'notifications']);
      expect(
        logger.lines,
        contains(
          '[notify] action tapped action=dismiss place=회사 handled=background',
        ),
      );
    });

    test('다른 버튼·본문 탭은 건드리지 않는다', () async {
      final calls = <String>[];
      for (final actionId in [null, 'other']) {
        await handleNotificationActionInBackground(
          _response(actionId),
          relay: (_) async {
            calls.add('relay');
            return true;
          },
          clearPending: () async => calls.add('pending'),
          clearNotifications: () async => calls.add('notifications'),
        );
      }
      expect(calls, isEmpty);
    });

    test('앱 isolate 포트가 없으면 넘기지 못한 것으로 본다', () async {
      expect(
        await relayNotificationActionToApp('회사', lookup: (_) => null),
        isFalse,
      );
    });
  });
}
