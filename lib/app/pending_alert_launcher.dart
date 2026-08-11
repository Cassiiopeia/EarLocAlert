import '../features/alert/domain/alert_controller.dart';
import 'background/pending_alert.dart';
import 'background/pending_alert_store.dart';

/// 백그라운드 알림을 포그라운드 풀 세션으로 잇는 진입로 (이슈 #63)
///
/// 백그라운드는 OS 알림 + PendingAlert 저장까지만 한다. 사용자가 앱을
/// 열면(알림 탭이든 직접 실행이든) 여기서 반복 진동·오디오 판정이 있는
/// 정식 알림 세션(AlertController)으로 승격한다.
class PendingAlertLauncher {
  PendingAlertLauncher({
    required PendingAlertStore store,
    required DateTime Function() clock,
    this.timeToLive = const Duration(minutes: 10),
  }) : _store = store,
       _clock = clock;

  final PendingAlertStore _store;
  final DateTime Function() _clock;

  /// 이 시간이 지난 알림은 버린다 — 한밤중 도착 알림을 아침에 열었을 때
  /// 진동이 터지는 것은 알림이 아니라 오작동이다. OS 알림은 이미
  /// 트레이에 남아 있으므로 정보는 사라지지 않는다.
  final Duration timeToLive;

  /// 미처리 알림을 꺼낸다.
  ///
  /// [request] 는 지금 승격할 알림이다. 만료됐거나 값이 깨졌으면 null 이다.
  ///
  /// [hadPending] 은 **꺼낼 것이 있었는지**다. 승격하지 못한 경우에도
  /// true 이며, 이때 네이티브는 그 알림으로 여전히 진동하고 있다.
  /// 호출자는 이 값이 true 이면 **반드시 네이티브 알림을 정리해야 한다** —
  /// 그러지 않으면 울리는데 끌 화면이 없는 상태가 된다 (이슈 #83).
  Future<({AlertRequest? request, bool hadPending})> takeRequest() async {
    final (:alert, :hadStored) = await _store.take();
    if (alert == null) return (request: null, hadPending: hadStored);

    final age = _clock().toUtc().difference(alert.occurredAt);
    if (age > timeToLive || age.isNegative) {
      return (request: null, hadPending: true);
    }

    return (
      request: AlertRequest(
        placeId: alert.placeId,
        placeName: alert.placeName,
        direction: alert.direction,
        soundEnabled: alert.soundEnabled,
        occurredAt: alert.occurredAt,
      ),
      hadPending: true,
    );
  }
}
