import '../core/diagnostics/diagnostics.dart';
import 'background/arrival_alarm_channel.dart';

/// 화면 없이 시작한 알림 세션에 잠금 화면 알람을 붙이고 떼는 조율자 (이슈 #235)
///
/// **알람은 화면만 덮는다.** 진동과 이어폰 소리는 여전히 `AlertController`
/// 세션이 맡는다 — 알람음은 무음이라(결정 057) 이어폰 허용 목록 판정
/// (CLAUDE.md 규칙 2)을 건드리지 않는다.
///
/// 두 화면이 겹치지 않게 한다:
/// - 세션이 끝나면(어디서 해제하든) 알람도 끈다
/// - 앱이 전면으로 오면 알림 화면이 대신하므로 알람을 끈다
/// - 사용자가 잠금 화면에서 알람을 끄면 세션도 끈다 — 알람만 꺼지고 진동이
///   계속되면 "껐는데 왜 떨지"가 된다. **광고는 띄우지 않는다** (화면 없는 해제)
class ArrivalAlarmCoordinator {
  ArrivalAlarmCoordinator({
    required ArrivalAlarmPlatform platform,
    required bool Function() isRinging,
    required Future<void> Function() dismissSession,
  }) : _platform = platform,
       _isRinging = isRinging,
       _dismissSession = dismissSession;

  final ArrivalAlarmPlatform _platform;
  final bool Function() _isRinging;
  final Future<void> Function() _dismissSession;

  /// 지금 떠 있는 우리 알람. 끄기 전에 비워서, 그 뒤 네이티브가 "꺼졌다"고
  /// 알려와도 세션을 두 번 끄지 않는다
  String? _presentedId;

  /// 띄우는 중이다 — 그 사이 세션이 끝나면 다 띄운 뒤 바로 끈다
  bool _presenting = false;

  bool _attached = false;

  String? get presentedId => _presentedId;

  /// 네이티브의 "사용자가 껐다" 신호를 받기 시작한다. 여러 번 불러도 한 번만 단다
  void attach() {
    if (_attached) return;
    _attached = true;
    _platform.setStopHandler(_onStopped);
  }

  /// 화면 없이 세션이 시작됐다 — 쓸 수 있으면 잠금 화면 알람을 띄운다.
  /// **던지지 않는다.** 못 띄워도 알림과 진동은 이미 나가고 있다.
  Future<void> present({
    required String placeName,
    required String title,
    required String stopLabel,
    required String openLabel,
  }) async {
    final status = await _platform.status();
    if (!status.supported) {
      Diagnostics.log('alarm', 'skipped place=$placeName reason=unsupported');
      return;
    }
    if (!status.usable) {
      Diagnostics.log(
        'alarm',
        'skipped place=$placeName reason=not_authorized '
            'auth=${status.authorization.name}',
      );
      return;
    }
    if (!_isRinging()) {
      // 상태를 묻는 사이 해제됐다
      Diagnostics.log('alarm', 'skipped place=$placeName reason=session_ended');
      return;
    }

    _presenting = true;
    // 네이티브로 넘기기 직전 (이슈 #241) — 경계 양쪽에 남겨야 어디서 멈췄는지 갈린다
    Diagnostics.log('alarm', 'presenting place=$placeName');
    final String id;
    try {
      id = await _platform.present(
        title: title,
        stopLabel: stopLabel,
        openLabel: openLabel,
      );
    } on Object catch (error) {
      Diagnostics.log(
        'alarm',
        'skipped place=$placeName reason=failed error=$error',
      );
      return;
    } finally {
      _presenting = false;
    }

    if (!_isRinging()) {
      // 띄우는 사이 해제됐다 — 꺼진 세션의 알람이 남으면 안 된다
      Diagnostics.log(
        'alarm',
        'presented after session end, stopping place=$placeName id=$id',
      );
      await _platform.stopAll('session_ended');
      return;
    }
    _presentedId = id;
    Diagnostics.log('alarm', 'presented place=$placeName id=$id');
  }

  /// 세션이 끝났다(해제) — 알람도 끈다
  Future<void> onSessionEnded() => _stop('dismissed');

  /// 앱이 전면으로 왔다 — 알림 화면이 대신하므로 알람을 끈다
  Future<void> onForeground() => _stop('foreground');

  Future<void> _stop(String reason) async {
    final id = _presentedId;
    if (id == null) return;
    _presentedId = null;
    Diagnostics.log('alarm', 'stopping id=$id reason=$reason');
    await _platform.stopAll(reason);
  }

  Future<void> _onStopped(String id) async {
    if (id != _presentedId) {
      // 우리가 먼저 끈 알람이거나 지난 알람이다 — 세션은 이미 정리됐다
      Diagnostics.log(
        'alarm',
        'stop ignored id=$id reason=${_presenting ? 'presenting' : 'not_current'}',
      );
      return;
    }
    _presentedId = null;
    if (!_isRinging()) {
      Diagnostics.log('alarm', 'stopped by user id=$id session=none');
      return;
    }
    Diagnostics.log('alarm', 'stopped by user id=$id, dismissing session');
    try {
      await _dismissSession();
    } on Object catch (error) {
      Diagnostics.log('alarm', 'session dismiss failed id=$id error=$error');
    }
  }

  /// 아직 묻지 않았으면 한 번 묻는다 (iOS 26+). 이미 정해졌거나 지원하지 않으면
  /// 아무것도 하지 않는다. **던지지 않는다.**
  Future<ArrivalAlarmAuthorization?> requestIfUndetermined(
    String trigger,
  ) async {
    final status = await _platform.status();
    if (!status.supported ||
        status.authorization != ArrivalAlarmAuthorization.notDetermined) {
      return null;
    }
    return requestAuthorization(trigger);
  }

  /// 권한을 묻고 결과를 남긴다
  Future<ArrivalAlarmAuthorization> requestAuthorization(String trigger) async {
    final result = await _platform.requestAuthorization();
    Diagnostics.log(
      'alarm',
      'authorization requested trigger=$trigger result=${result.name}',
    );
    return result;
  }
}
