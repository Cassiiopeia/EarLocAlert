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

  /// 알림 화면이 떠 있는 동안의 **돌아오는 통로**다 — 튀어나오지 않는다.
  ///
  /// 예전 채널(`ear_loc_alert_alarm`)은 중요도 최대라 알림 화면이 뜨는
  /// 바로 그 순간 헤드업이 화면 위를 덮어 장소명을 가렸다 (이슈 #142 QA).
  /// 이 세션은 앱이 전면에 있을 때만 시작되므로 알릴 일은 화면이 이미
  /// 하고 있다. **채널 중요도는 생성 뒤 바꿀 수 없어** 새 이름으로 옮긴다
  static const String _channelId = 'ear_loc_alert_session';

  /// 옛 채널 — 기존 설치의 설정 화면에 남지 않게 앱 시작 때 지운다
  static const String legacyChannelId = 'ear_loc_alert_alarm';

  @override
  Future<void> show({required String placeName, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      '알림 진행 중',
      channelDescription: '알림 화면을 벗어났을 때 다시 돌아오는 알림입니다',
      // 헤드업을 띄우지 않는다 — 상태바와 알림 목록에만 남는다
      importance: Importance.low,
      priority: Priority.low,
      // 진동은 AlertController 가 직접 제어한다 —
      // 알림 채널 진동과 겹치면 패턴이 어긋난다
      enableVibration: false,
      playSound: false,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      // 앱이 전면일 때 배너를 띄우지 않는다 — 알림 화면을 덮는다
      presentBanner: false,
      presentList: true,
      presentBadge: false,
      // 소리는 이어폰 연결 시에만 앱이 직접 재생한다 (F3.7)
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
