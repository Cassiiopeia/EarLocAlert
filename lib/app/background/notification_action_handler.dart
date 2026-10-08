import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/diagnostics/diagnostic_log_file.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/platform/notification_actions.dart';
import '../../features/alert/data/alert_notifier_impl.dart';
import 'background_alert_notifier.dart';
import 'pending_alert_store.dart';

/// 앱 isolate 가 알림 버튼 눌림을 받는 포트 이름 (이슈 #237)
///
/// 앱을 띄우지 않는 버튼은 `flutter_local_notifications` 가 **별도 헤드리스
/// 엔진**에서 처리한다. 앱 엔진이 살아 있어도 그쪽으로는 오지 않는다. 같은 Dart VM
/// 이라 `IsolateNameServer` 로 앱 isolate 를 찾아 넘긴다 (영역 이벤트 #231 과 같은 길).
const notificationActionPortName =
    'kr.suhsaechan.ear_loc_alert/notification_action';

/// 알림 버튼 처리기 — 플러그인이 헤드리스 엔진에서 부른다 (이슈 #237).
///
/// **최상위 함수여야 하고 진입점 표시가 있어야 한다.** 릴리스 빌드에서 트리
/// 셰이킹으로 지워지면 버튼을 눌러도 아무 일도 일어나지 않는다.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  unawaited(handleNotificationActionInBackground(response));
}

/// 헤드리스 엔진에서의 처리 (이슈 #237).
///
/// 앱 isolate 가 살아 있으면 그쪽이 세션을 끈다 — 진동·반복 알림·잠금 화면 알람은
/// 전부 앱 isolate 가 들고 있다. 없으면 여기서 할 수 있는 만큼(대기 알림·알림 정리)만
/// 한다. **앱을 띄우지 않는다** — 끄려고 누른 사람에게 화면을 보여줄 이유가 없다.
@visibleForTesting
Future<void> handleNotificationActionInBackground(
  NotificationResponse response, {
  Future<bool> Function(String place)? relay,
  Future<void> Function()? clearPending,
  Future<void> Function()? clearNotifications,
}) async {
  if (response.actionId != NotificationActions.dismiss) return;
  try {
    // 헤드리스 엔진은 플러그인 등록을 직접 해야 SharedPreferences·알림을 쓴다
    DartPluginRegistrant.ensureInitialized();
  } on Object {
    // 테스트 환경 등 — 아래 단계가 각자 실패를 기록한다
  }
  await Diagnostics.init(source: DiagnosticLogSource.background);

  final place = response.payload ?? 'unknown';
  // 경계를 넘을 때 남긴다 — 앱 쪽 기록이 없으면 여기서 멈췄다는 뜻이다 (#125)
  Diagnostics.log(
    'notify',
    'action received action=dismiss place=$place engine=background',
  );

  final handledByApp = await (relay ?? relayNotificationActionToApp)(place);
  if (handledByApp) return;

  // 앱 isolate 가 없다 — 세션도 진동도 없으니 남은 흔적만 치운다. 대기 알림을
  // 남기면 다음에 앱을 여는 순간 이미 끈 알림이 다시 울린다
  try {
    await (clearPending ?? _takePendingAlert)();
  } on Object catch (error) {
    Diagnostics.log('notify', 'action pending clear failed error=$error');
  }
  try {
    await (clearNotifications ?? _cancelAlertNotifications)();
  } on Object catch (error) {
    Diagnostics.log('notify', 'action notification clear failed error=$error');
  }
  Diagnostics.log(
    'notify',
    'action tapped action=dismiss place=$place handled=background',
  );
}

Future<void> _takePendingAlert() async {
  await PendingAlertStore().take();
}

Future<void> _cancelAlertNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  for (final id in [
    ...BackgroundAlertNotifier.notificationIds,
    AlertNotifierImpl.notificationId,
  ]) {
    await plugin.cancel(id);
  }
}

/// 버튼 눌림을 앱 isolate 로 넘긴다. 앱이 끝까지 처리했으면 true.
///
/// 앱 isolate 가 없거나(포트 없음) 제때 답하지 않으면 false — 호출자가 직접 정리한다.
Future<bool> relayNotificationActionToApp(
  String place, {
  Duration timeout = const Duration(seconds: 5),
  SendPort? Function(String name) lookup = IsolateNameServer.lookupPortByName,
}) async {
  final target = lookup(notificationActionPortName);
  if (target == null) {
    Diagnostics.log('notify', 'action relay skipped reason=no_app_isolate');
    return false;
  }
  final reply = ReceivePort();
  try {
    target.send({'place': place, 'reply': reply.sendPort});
    final answer = await reply.first.timeout(timeout);
    if (answer == 'ok') return true;
    Diagnostics.log(
      'notify',
      'action relay failed reason=app_error detail=$answer',
    );
    return false;
  } on TimeoutException {
    // 죽은 포트(앱 isolate 가 사라진 뒤 남은 이름)로 보내면 답이 영영 없다
    Diagnostics.log('notify', 'action relay failed reason=timeout');
    return false;
  } finally {
    reply.close();
  }
}

/// 앱 isolate 쪽 수신기 (이슈 #237)
class NotificationActionReceiver {
  NotificationActionReceiver({
    required Future<void> Function(String place) onDismiss,
  }) : _onDismiss = onDismiss;

  final Future<void> Function(String place) _onDismiss;
  ReceivePort? _port;

  /// 포트를 이름으로 건다. 지난 실행이 남긴 이름이 있으면 먼저 지운다
  void attach() {
    if (_port != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(notificationActionPortName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      notificationActionPortName,
    );
    port.listen(_onMessage);
    _port = port;
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! Map) return;
    final place = message['place'] as String? ?? 'unknown';
    final reply = message['reply'] as SendPort?;
    // 받은 쪽 기록 — 보낸 쪽 기록과 짝을 이룬다 (#125)
    Diagnostics.log(
      'notify',
      'action received action=dismiss place=$place engine=app',
    );
    try {
      await _onDismiss(place);
      reply?.send('ok');
    } on Object catch (error) {
      Diagnostics.log(
        'notify',
        'action handling failed place=$place error=$error',
      );
      reply?.send('error:$error');
    }
  }

  void detach() {
    IsolateNameServer.removePortNameMapping(notificationActionPortName);
    _port?.close();
    _port = null;
  }
}
