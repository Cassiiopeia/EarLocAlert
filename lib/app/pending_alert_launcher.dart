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

  /// 미처리 알림이 있으면 꺼내 발화 요청으로 바꾼다. 없거나 만료면 null.
  Future<AlertRequest?> takeRequest() async {
    final PendingAlert? pending = await _store.take();
    if (pending == null) return null;

    final age = _clock().toUtc().difference(pending.occurredAt);
    if (age > timeToLive || age.isNegative) return null;

    return AlertRequest(
      placeId: pending.placeId,
      placeName: pending.placeName,
      direction: pending.direction,
      soundEnabled: pending.soundEnabled,
      occurredAt: pending.occurredAt,
    );
  }
}
