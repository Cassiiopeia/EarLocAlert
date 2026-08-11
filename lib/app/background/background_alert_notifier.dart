import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/domain/alert_direction.dart';
import 'background_alert_port.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';

/// 백그라운드 알림 발행 구현 (이슈 #63, #74)
///
/// **채널을 포그라운드 알림(ear_loc_alert_alarm)과 분리한다.**
/// 그 채널은 진동 off 다 — AlertController 가 직접 반복 진동을 돌리기
/// 때문이다. 백그라운드 isolate 는 콜백 후 즉시 죽어 진동 루프를 돌릴 수
/// 없으므로, 여기서는 채널의 진동 패턴에 위임한다. Android 채널 설정은
/// 최초 생성 시 고정되므로 채널을 공유하면 한쪽 요구가 반드시 깨진다.
///
/// **이 알림 하나로 끝나지 않는다** (이슈 #74). 저장된 PendingAlert 를
/// 네이티브 감시 서비스(AlertWatchService)가 감지해 반복 진동을 걸고 앱을
/// 전면으로 띄운다. 서비스가 없거나 권한이 없는 경우에 남는 것이 이
/// 알림이므로, 그 상황에서도 성립하도록 채널 진동을 유지한다.
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

  /// 오버레이 권한이 없을 때 **해제 화면에 닿는 유일한 길**이 이 알림이다.
  /// 앱이 승격하거나 정리할 때 지워야 하므로 id 를 공개한다 (이슈 #84).
  static const int notificationId = 2001;

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
      // 화면이 꺼졌거나 잠겼을 때 알림 화면을 띄운다. 화면이 켜져 있으면
      // OS 가 헤드업으로 강등하는데, 그 경우는 감시 서비스가 앱을 전면으로
      // 올려 처리한다 (docs/10-DECISIONS.md 006 재검토, 이슈 #74).
      fullScreenIntent: true,
      // 알람으로 분류한다 — Android 14+ 의 전체화면 알림 자동 부여 대상이
      // 알람·통화 계열이고, 잠금화면 노출과 헤드업 우선순위도 이 값을 본다.
      category: AndroidNotificationCategory.alarm,
      // 잠금화면에서 내용까지 보여준다. 장소 이름을 봐야 내릴지 판단한다.
      visibility: NotificationVisibility.public,
      // 탭해서 앱으로 들어오면 사라진다.
      autoCancel: true,
      // **스와이프로는 지워지지 않는다** (이슈 #84). 오버레이·전체화면
      // 권한이 없으면 알림 화면이 저절로 뜨지 않으므로, 이 알림이 해제
      // 화면에 닿는 유일한 길이다. 실수로 쓸어 넘기면 진동은 계속되는데
      // 끌 방법이 사라진다.
      //
      // 지우는 책임은 앱에 있다 — 승격하거나 정리할 때 반드시 취소한다.
      // 그러지 않으면 이번엔 영영 남는 알림이 된다.
      ongoing: true,
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
