import 'dart:typed_data';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/domain/alert_direction.dart';
import '../../core/l10n/app_language_store.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_resolver.dart';
import '../../core/platform/notification_actions.dart';
import 'background_alert_port.dart';
import 'notification_action_handler.dart';
import 'pending_alert.dart';
import 'pending_alert_store.dart';

/// 백그라운드 알림 발행 구현 (이슈 #63, #74)
///
/// **채널을 포그라운드 알림(ear_loc_alert_session)과 분리한다.**
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

  /// 반복 알림이 번갈아 쓰는 두 번째 id (이슈 #233). 같은 id 로 다시 내면
  /// 이미 떠 있는 알림을 갱신할 뿐 진동이 다시 나는지 보장되지 않아, 두 id 를
  /// 번갈아 내고 앞의 것을 지운다 — 알림 목록에는 늘 하나만 남는다.
  static const int reminderNotificationId = 2002;

  /// 앱이 정리할 때 함께 지워야 하는 id 전부
  static const List<int> notificationIds = [
    notificationId,
    reminderNotificationId,
  ];

  static const String _channelId = 'ear_loc_alert_geofence';

  @override
  Future<void> notify(PendingAlert alert) async {
    // 저장이 먼저다 — 알림 발행이 실패해도 앱을 열면 알림이 이어진다
    await _store.save(alert);
    await _post(alert, id: notificationId);
    // 실기기에서 "알림은 떴는데 진동이 없었다"를 가르는 단서다 (이슈 #221)
    Diagnostics.log(
      'notify',
      'background notification posted place=${alert.placeName} '
          'direction=${alert.direction.name} ios_sound=$iosSilentHapticSound',
    );
  }

  /// 같은 알림을 다시 내 진동을 한 번 더 일으킨다 (이슈 #233).
  ///
  /// iOS 는 백그라운드에서 반복 진동을 걸 수 없어 알림 한 번에 진동 한 번이다
  /// (결정 053). 앱 세션이 화면 없이 울리는 동안 이것을 몇 번 반복해 주머니 속
  /// 기기가 계속 떨게 한다. **대기 알림은 저장하지 않는다** — 세션이 이미 그것을
  /// 꺼내 돌고 있다. 소리는 여전히 무음 파일이다 (CLAUDE.md 규칙 2).
  Future<void> remind(PendingAlert alert, {required int sequence}) async {
    final id = sequence.isOdd ? reminderNotificationId : notificationId;
    final previous = id == notificationId
        ? reminderNotificationId
        : notificationId;
    await _post(alert, id: id);
    // 새 것을 낸 뒤에 앞의 것을 지운다 — 순서가 뒤집히면 잠깐 아무것도 없다
    await _plugin.cancel(previous);
    Diagnostics.log(
      'notify',
      'background reminder posted place=${alert.placeName} n=$sequence '
          'ios_sound=$iosSilentHapticSound',
    );
  }

  Future<void> _post(PendingAlert alert, {required int id}) async {
    final strings = await _loadStrings();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      strings.notificationChannelName,
      channelDescription: strings.notificationChannelDescription,
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

    // **iOS 는 소리 없는 알림에 진동도 붙이지 않는다** (이슈 #221).
    // 무음으로 보냈더니 주머니 속 기기에서는 배너만 조용히 떠서, 앱을 연
    // 순간에야 알림 화면이 진동했다. 그래서 무음 파일을 소리로 지정해
    // 시스템 진동만 나게 한다 — 들리는 소리는 없다 (CLAUDE.md 규칙 2).
    //
    // **파일은 앱 번들에 있어야 한다.** 지정한 이름을 못 찾으면 iOS 가
    // 기본 알림음을 스피커로 낸다. 런타임에 복사하는 방식은 쓰지 않는다.
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      sound: iosSilentHapticSound,
      interruptionLevel: InterruptionLevel.timeSensitive,
      // 앱을 열지 않고 끄는 "알림 끄기" 버튼 (이슈 #237). iOS 26 미만은 잠금 화면을
      // 덮지 못해 끄려면 앱을 열어야 했다
      categoryIdentifier: NotificationActions.arrivalCategory,
    );

    await _plugin.show(
      id,
      alert.placeName,
      alert.direction == AlertDirection.exit
          ? strings.notificationLeft
          : strings.notificationArrived,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      // 버튼 눌림 기록에 어느 장소였는지 남기려고 싣는다 (이슈 #237)
      payload: alert.placeName,
    );
  }
}

/// 알림 플러그인 초기화 설정 — 앱·백그라운드 isolate 가 같은 값을 쓴다.
/// 권한 요청은 온보딩이 담당하므로 여기서는 요청하지 않는다.
///
/// **iOS 카테고리를 여기서 등록한다** (이슈 #237). 알림의 "알림 끄기" 버튼은
/// 초기화 때 등록한 카테고리로만 생긴다. 버튼 이름은 그때의 앱 언어로 고정되고,
/// 다음 초기화(앱 재시작)에서 바뀐 언어를 따른다.
///
/// **앱을 띄우지 않는 버튼이다** (`foreground` 옵션 없음). 끄려고 누른 사람에게
/// 잠금 해제와 앱 화면을 요구하지 않는다 — 진동을 멈추는 것이 전부다.
InitializationSettings buildNotificationInitSettings(AppLocalizations strings) {
  return InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          NotificationActions.arrivalCategory,
          actions: [
            DarwinNotificationAction.plain(
              NotificationActions.dismiss,
              strings.notificationActionDismiss,
              options: const {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    ),
  );
}

/// 앱 언어로 초기화 설정을 만든다. 문구를 못 구해도 영어로 만든다 — 던지지 않는다
Future<InitializationSettings> loadNotificationInitSettings() async =>
    buildNotificationInitSettings(await _loadStrings());

final _initialized = Expando<Future<void>>('notifications initialized');

/// 플러그인을 한 번만 초기화한다 (이슈 #231).
///
/// iOS 가 위치 사유로 앱을 백그라운드에서 다시 띄우면 첫 프레임이 오지 않아
/// 앱 부트스트랩(여기서 초기화한다)이 돌지 않는다. 그 상태에서 도착 알림을
/// 내려면 발행 직전에 초기화돼 있어야 한다. 실패하면 다음 호출에서 다시 시도한다.
///
/// 버튼 눌림 처리기도 함께 단다 (이슈 #237) — 이 경로로 낸 알림에도 버튼이 붙는다.
Future<void> ensureNotificationsInitialized(
  FlutterLocalNotificationsPlugin plugin,
) {
  final existing = _initialized[plugin];
  if (existing != null) return existing;
  final attempt = loadNotificationInitSettings()
      .then(
        (settings) => plugin.initialize(
          settings,
          onDidReceiveBackgroundNotificationResponse:
              onBackgroundNotificationResponse,
        ),
      )
      .then<void>(
        (_) {},
        onError: (Object error) {
          // 실패한 시도를 기억하지 않는다 — 다음 알림에서 다시 초기화한다
          _initialized[plugin] = null;
          throw error;
        },
      );
  _initialized[plugin] = attempt;
  return attempt;
}

/// iOS 백그라운드 알림의 소리 파일 — 1초 무음 (이슈 #221).
///
/// `ios/Runner/silent_haptic.caf` 로 번들에 들어 있다. 이름을 바꾸면
/// Xcode 프로젝트의 리소스 항목도 함께 바꿔야 한다.
const iosSilentHapticSound = 'silent_haptic.caf';

/// 알림 문구의 언어를 구한다 (이슈 #163).
///
/// 백그라운드 isolate 는 `BuildContext` 가 없고 저장소 캐시도 앱과 따로라,
/// 저장된 언어를 **다시 읽어** 최신 값을 본다. **문구를 못 구해도 알림은
/// 반드시 나가야 하므로** 어떤 실패든 삼키고 영어로 떨어진다.
Future<AppLocalizations> _loadStrings() async {
  try {
    final language = await const AppLanguageStore().readFresh();
    final locale = resolveAppLocale(
      language,
      PlatformDispatcher.instance.locales,
    );
    Diagnostics.log(
      'notify',
      'notification language preference=${language.storageValue} '
          'resolved=${locale.languageCode}',
    );
    return AppStrings.forLocale(locale);
  } on Object catch (error) {
    Diagnostics.log('notify', 'notification language lookup failed $error');
    return AppStrings.forLocale(fallbackAppLocale);
  }
}

/// 대기(0.5초)·진동(1초) 반복 — 놓치기 어렵게 길게 가져간다.
/// Int64List 는 flutter_local_notifications 가 요구하는 타입이다.
final _vibrationPattern = (() {
  const pattern = [500, 1000, 500, 1000, 500, 1000, 500, 1000];
  return Int64List.fromList(pattern);
})();
