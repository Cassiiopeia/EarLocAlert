import 'package:ear_loc_alert/app/background/background_alert_notifier.dart';
import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 반복 알림 (이슈 #233) — 진동을 한 번 더 일으키되 소리는 여전히 무음이고,
/// 알림 목록에는 하나만 남는다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final alert = PendingAlert(
    placeId: 'p1',
    placeName: '테스트 위치',
    direction: AlertDirection.enter,
    soundEnabled: true,
    occurredAt: DateTime.utc(2026, 10, 8),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('두 id 를 번갈아 내고 앞의 것을 지운다', () async {
    final plugin = _FakePlugin();
    final notifier = BackgroundAlertNotifier(
      plugin: plugin,
      store: PendingAlertStore(),
    );

    await notifier.remind(alert, sequence: 1);
    await notifier.remind(alert, sequence: 2);

    expect(plugin.calls, [
      'show ${BackgroundAlertNotifier.reminderNotificationId}',
      'cancel ${BackgroundAlertNotifier.notificationId}',
      'show ${BackgroundAlertNotifier.notificationId}',
      'cancel ${BackgroundAlertNotifier.reminderNotificationId}',
    ]);
  });

  test('소리는 무음 파일이다 — 들리는 소리를 내지 않는다 (CLAUDE.md 규칙 2)', () async {
    final plugin = _FakePlugin();

    await BackgroundAlertNotifier(
      plugin: plugin,
      store: PendingAlertStore(),
    ).remind(alert, sequence: 1);

    final ios = plugin.details.single.iOS!;
    expect(ios.sound, iosSilentHapticSound);
    expect(plugin.details.single.android!.playSound, isFalse);
  });

  test('대기 알림을 다시 저장하지 않는다 — 세션이 이미 꺼내 쓰고 있다', () async {
    await BackgroundAlertNotifier(
      plugin: _FakePlugin(),
      store: PendingAlertStore(),
    ).remind(alert, sequence: 1);

    expect(await PendingAlertStore().hasPending(), isFalse);
  });

  test('앱이 정리할 때 두 id 를 모두 지운다', () {
    expect(BackgroundAlertNotifier.notificationIds, [
      BackgroundAlertNotifier.notificationId,
      BackgroundAlertNotifier.reminderNotificationId,
    ]);
  });
}

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final List<String> calls = [];
  final List<NotificationDetails> details = [];

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    calls.add('show $id');
    if (notificationDetails != null) details.add(notificationDetails);
  }

  @override
  Future<void> cancel(int id, {String? tag}) async => calls.add('cancel $id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
