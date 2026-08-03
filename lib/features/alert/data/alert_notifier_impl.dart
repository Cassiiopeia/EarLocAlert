import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/alert_effects.dart';

/// OS 알림 발행 구현 (F3.2)
///
/// **전체화면 알림을 전제하지 않는다** (docs/10-DECISIONS.md 006).
/// Android 14+ 는 `USE_FULL_SCREEN_INTENT` 자동 부여가 알람·통화 계열로
/// 제한되고 iOS 에는 개념 자체가 없다. 높은 중요도 알림 + 반복 진동만으로
/// 앱이 성립해야 한다.
class AlertNotifierImpl implements AlertNotifier {
  AlertNotifierImpl(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const int _notificationId = 1001;
  static const String _channelId = 'ear_loc_alert_alarm';

  @override
  Future<void> show({required String placeName, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      '위치 알림',
      channelDescription: '등록한 장소에 도착하거나 떠날 때 알립니다',
      importance: Importance.max,
      priority: Priority.high,
      // 진동은 AlertController 가 직접 제어한다 —
      // 알림 채널 진동과 겹치면 패턴이 어긋난다
      enableVibration: false,
      playSound: false,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      // 소리는 블루투스 연결 시에만 앱이 직접 재생한다 (F3.7)
      presentSound: false,
    );

    await _plugin.show(
      _notificationId,
      placeName,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  @override
  Future<void> dismiss() async {
    await _plugin.cancel(_notificationId);
  }
}
