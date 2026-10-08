import 'dart:async';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/domain/alert_controller.dart';
import '../features/alert/domain/audio_route.dart';
import 'background/pending_alert.dart';

/// 화면 없이 결정된 iOS 알림을 실제 세션으로 바로 울린다 (이슈 #233, 결정 055)
///
/// **앱을 열 때까지 소리를 미뤘다.** iOS 적응형 감시(결정 054) 덕분에 앱
/// isolate 가 백그라운드에서도 살아 있는데, 도착이 정해지면 무음 햅틱 알림만
/// 내고 끝났다. 실기기에서 이어폰을 끼고 있었는데도 소리는 사용자가 12초 뒤
/// 앱을 연 순간에야 났다 — 버스에서 그 12초면 정거장을 지난다.
///
/// 하는 일:
/// 1. 대기 알림을 꺼내 알림 화면과 **같은 세션**(`AlertController`)을 시작한다 —
///    이어폰 허용 목록 판정·장소 설정이 그대로 적용된다 (CLAUDE.md 규칙 2)
/// 2. 세션이 울리는 동안 무음 햅틱 알림을 몇 번 더 낸다 — iOS 백그라운드에서는
///    앱이 직접 거는 진동을 믿을 수 없고, 알림 한 번에 진동 한 번이라서다 (결정 053)
/// 3. 해제되거나 화면이 뜨면 반복을 멈추고 알림을 지운다
///
/// 대기 알림을 여기서 소비하므로 앱을 열 때 승격 경로가 같은 알림으로 두 번째
/// 세션을 만들지 않는다. 사용자가 열면 이미 도는 세션의 알림 화면에 닿는다.
class BackgroundAlertRinger {
  BackgroundAlertRinger({
    required Future<AlertRequest?> Function() takeRequest,
    required Future<bool> Function(AlertRequest request) startSession,
    required Future<AudioRoute?> Function() audioDecision,
    required Future<void> Function(PendingAlert alert, int sequence) remind,
    required Future<void> Function() clearNotifications,
    required bool Function() isRinging,
    this.reminderInterval = const Duration(seconds: 10),
    this.maxReminders = 12,
    this.audioDecisionTimeout = const Duration(seconds: 5),
  }) : _takeRequest = takeRequest,
       _startSession = startSession,
       _audioDecision = audioDecision,
       _remind = remind,
       _clearNotifications = clearNotifications,
       _isRinging = isRinging;

  final Future<AlertRequest?> Function() _takeRequest;

  /// 세션을 새로 시작했으면 true. 이미 울리는 중이라 버렸거나 줄 세웠으면 false
  final Future<bool> Function(AlertRequest request) _startSession;
  final Future<AudioRoute?> Function() _audioDecision;
  final Future<void> Function(PendingAlert alert, int sequence) _remind;
  final Future<void> Function() _clearNotifications;
  final bool Function() _isRinging;

  /// 반복 알림 간격. 짧으면 알림 목록이 요동치고, 길면 주머니 속에서 놓친다
  final Duration reminderInterval;

  /// 반복 상한 — 기본 2분. 그 뒤에도 세션(이어폰 소리)은 해제까지 이어진다.
  /// 끝없이 떨게 두면 잊고 내린 사용자의 배터리와 인내가 같이 닳는다
  final int maxReminders;

  /// 오디오 판정을 기다릴 상한 — 결과 한 줄을 남기려는 것뿐이라 오래 기다리지 않는다
  final Duration audioDecisionTimeout;

  Timer? _reminders;
  int _sent = 0;

  /// 이 객체가 시작한 세션이 화면 없이 울리는 중인가
  bool _active = false;

  bool get isActive => _active;

  /// 화면 없이 결정된 알림 하나를 울린다. **던지지 않는다.**
  Future<void> ring(PendingAlert alert) async {
    final AlertRequest? request;
    try {
      request = await _takeRequest();
    } on Object catch (error) {
      Diagnostics.log(
        'alert',
        'background session not started place=${alert.placeName} '
            'reason=take_failed error=$error',
      );
      return;
    }
    if (request == null) {
      // 승격 경로(앱 열림)가 먼저 꺼냈거나 만료됐다 — 그쪽이 세션을 맡는다
      Diagnostics.log(
        'alert',
        'background session not started place=${alert.placeName} '
            'reason=no_pending',
      );
      return;
    }

    final bool started;
    try {
      started = await _startSession(request);
    } on Object catch (error) {
      // 무음 햅틱 알림은 이미 나갔다 — 앱을 열면 대기 알림 없이 알림 기록만 남는다
      Diagnostics.log(
        'alert',
        'background session not started place=${request.placeName} '
            'reason=start_failed error=$error',
      );
      return;
    }
    if (!started) {
      // 다른 장소 알림이 울리는 중이면 컨트롤러가 줄 세웠다. 반복은 앞 세션 것이 돈다
      Diagnostics.log(
        'alert',
        'background session not started place=${request.placeName} '
            'reason=already_ringing',
      );
      return;
    }

    _active = true;
    _startReminders(alert);

    // 판정이 늦으면 모른다고 남긴다 — 세션은 이미 울리고 있다
    // `then` 으로 nullable 로 넓힌다 — 런타임 타입이 Future<AudioRoute> 이면
    // timeout 의 null 반환이 타입 오류가 된다
    final route = await _audioDecision()
        .then<AudioRoute?>((value) => value)
        .timeout(audioDecisionTimeout, onTimeout: () => null);
    Diagnostics.log(
      'alert',
      'background session started place=${request.placeName} '
          'audio=${_describe(route)} '
          'reminders=${maxReminders}x${reminderInterval.inSeconds}s',
    );
  }

  /// 화면이 떴다 — 알림 화면이 대신하므로 반복 알림을 멈추고 지운다.
  /// 남겨 두면 알림 화면 위에 배너가 계속 덮인다.
  Future<void> onForeground() => _finish(reason: 'foreground');

  /// 세션이 끝났다(해제) — 반복 알림을 멈추고 남은 알림을 지운다
  Future<void> onSessionEnded() => _finish(reason: 'dismissed');

  Future<void> _finish({required String reason}) async {
    if (!_active) return;
    _active = false;
    _reminders?.cancel();
    _reminders = null;
    Diagnostics.log(
      'alert',
      'background reminders stopped reason=$reason sent=$_sent',
    );
    try {
      await _clearNotifications();
    } on Object catch (error) {
      // 남은 알림은 불편이지 고장이 아니다
      Diagnostics.log('alert', 'background notification clear failed $error');
    }
  }

  void _startReminders(PendingAlert alert) {
    _reminders?.cancel();
    _sent = 0;
    _reminders = Timer.periodic(reminderInterval, (timer) {
      // 해제가 스트림보다 먼저 와도 여기서 멈춘다 — 끈 뒤에 떨면 안 된다
      if (!_active || !_isRinging()) {
        timer.cancel();
        return;
      }
      if (_sent >= maxReminders) {
        timer.cancel();
        Diagnostics.log(
          'alert',
          'background reminders stopped reason=limit sent=$_sent',
        );
        return;
      }
      _sent++;
      unawaited(_remindSafely(alert, _sent));
    });
  }

  Future<void> _remindSafely(PendingAlert alert, int sequence) async {
    try {
      await _remind(alert, sequence);
      // 내는 사이 해제됐다 — 방금 낸 알림이 남지 않게 한 번 더 지운다
      if (!_active) await _clearNotifications();
    } on Object catch (error) {
      // 하나가 실패해도 다음 간격에 다시 낸다
      Diagnostics.log('alert', 'background reminder failed n=$sequence $error');
    }
  }

  static String _describe(AudioRoute? route) => switch (route) {
    AudioRoute.headphones => 'headphones',
    AudioRoute.silent => 'vibrate_only',
    null => 'undecided',
  };
}
