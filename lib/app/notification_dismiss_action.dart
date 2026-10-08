import '../core/diagnostics/diagnostics.dart';

/// 알림의 "알림 끄기" 버튼을 앱 isolate 에서 처리한다 (이슈 #237)
///
/// **알림 화면의 해제와 같은 세션 해제를 쓴다** — 진동·소리가 같은 길로 멈춘다.
/// **광고는 붙이지 않는다** (CLAUDE.md 규칙 1·3). 화면 없이 끈 것이라 그 뒤에 띄울
/// 화면이 없고, 잠금 화면에서 누른 사람에게 광고를 보이면 우발 클릭이 된다.
/// **화면을 옮기지 않는다** — 세션이 사라지면 알림 화면은 스스로 홈으로 간다.
///
/// 순서는 사용자가 느끼는 것부터다 — 진동이 먼저 멈춰야 한다. 한 단계가 실패해도
/// 나머지는 계속한다. 하나 남는 것이 전부 남는 것보다 낫다.
class NotificationDismissAction {
  NotificationDismissAction({
    required bool Function() isRinging,
    required Future<void> Function() dismissSession,
    required Future<void> Function() stopReminders,
    required Future<void> Function() stopAlarms,
    required Future<void> Function() clearPending,
    required Future<void> Function() clearNotifications,
  }) : _isRinging = isRinging,
       _dismissSession = dismissSession,
       _stopReminders = stopReminders,
       _stopAlarms = stopAlarms,
       _clearPending = clearPending,
       _clearNotifications = clearNotifications;

  final bool Function() _isRinging;
  final Future<void> Function() _dismissSession;
  final Future<void> Function() _stopReminders;
  final Future<void> Function() _stopAlarms;
  final Future<void> Function() _clearPending;
  final Future<void> Function() _clearNotifications;

  Future<void> run({required String place}) async {
    final ringing = _isRinging();
    Diagnostics.log(
      'notify',
      'action tapped action=dismiss place=$place handled=app '
          'session=${ringing ? "ringing" : "none"}',
    );
    if (ringing) await _step('dismiss_session', _dismissSession);
    // 세션 종료 신호로도 멈추지만, 세션이 없던 경우(이미 끝난 뒤 남은 알림)에도
    // 반복 알림과 잠금 화면 알람이 남지 않게 직접 부른다
    await _step('stop_reminders', _stopReminders);
    await _step('stop_alarms', _stopAlarms);
    // 대기 알림을 남기면 앱을 여는 순간 이미 끈 알림이 다시 울린다
    await _step('clear_pending', _clearPending);
    await _step('clear_notifications', _clearNotifications);
  }

  Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      Diagnostics.log('notify', 'action step failed step=$name error=$error');
    }
  }
}
