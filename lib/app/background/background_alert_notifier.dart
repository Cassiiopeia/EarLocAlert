import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/domain/alert_direction.dart';
import 'background_alert_port.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';

/// 백그라운드 알림 발행 구현 (이슈 #63)
///
/// **채널을 포그라운드 알림(ear_loc_alert_alarm)과 분리한다.**
/// 그 채널은 진동 off 다 — AlertController 가 직접 반복 진동을 돌리기
/// 때문이다. 백그라운드 isolate 는 콜백 후 즉시 죽어 진동 루프를 돌릴 수
/// 없으므로, 여기서는 채널의 진동 패턴에 위임한다. Android 채널 설정은
/// 최초 생성 시 고정되므로 채널을 공유하면 한쪽 요구가 반드시 깨진다.
///
/// 소리는 어떤 경우에도 채널에서 내지 않는다 — 이어폰 확인 없는 재생은
/// 스피커로 샐 수 있다 (F3.7, docs/03-DOMAIN.md 규칙 5).
class BackgroundAlertNotifier implements BackgroundAlertPort {
  BackgroundAlertNotifier({
    required FlutterLocalNotificationsPlugin plugin,
    required PendingAlertStore store,
  }) : _plugin = plugin,
       _store = store;

  final FlutterLocalNotificationsPlugin _plugin;
  final PendingAlertStore _store;

  static const int _notificationId = 2001;
  static const String _channelId = 'ear_loc_alert_geofence';

  @override
  Future<void> notify(PendingAlert alert) async {
    // 저장이 먼저다 — 알림 발행이 실패해도 앱을 열면 알림이 이어진다
    await _store.save(alert);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      '도착·출발 알림',
      channelDescription: '등록한 장소에 도착하거나 떠날 때 알립니다',
      importance: Importance.max,
      priority: Priority.high,
      // 앱 프로세스가 없으므로 진동은 채널에 위임한다
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      playSound: false,
      // 전체화면 인텐트는 되면 좋고 안 돼도 성립해야 한다
      // (docs/10-DECISIONS.md 006). 거부돼도 높은 중요도 알림은 뜬다.
      fullScreenIntent: true,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      _notificationId,
      alert.placeName,
      alert.direction == AlertDirection.exit ? '떠났습니다' : '도착했습니다',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

/// 대기(0.5초)·진동(1초) 반복 — 놓치기 어렵게 길게 가져간다.
/// Int64List 는 flutter_local_notifications 가 요구하는 타입이다.
final _vibrationPattern = (() {
  const pattern = [500, 1000, 500, 1000, 500, 1000, 500, 1000];
  return Int64List.fromList(pattern);
})();
