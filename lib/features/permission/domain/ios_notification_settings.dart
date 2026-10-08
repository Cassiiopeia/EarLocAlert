/// iOS 알림 권한 상태 (이슈 #237). 네이티브 문자열과 1:1 이다
enum IosNotificationAuthorization {
  notDetermined,
  denied,
  authorized,

  /// 조용한 전달 — 배너·소리·잠금 화면 없이 알림 센터에만 쌓인다
  provisional,

  /// 앱 클립 전용 임시 허용
  ephemeral,
  unknown;

  static IosNotificationAuthorization parse(Object? raw) =>
      values.firstWhere((value) => value.name == raw, orElse: () => unknown);
}

/// 항목 하나의 켜짐 상태 (`UNNotificationSetting`)
enum IosNotificationSetting {
  enabled,
  disabled,

  /// 이 기기·OS 에 없는 항목
  notSupported,
  unknown;

  static IosNotificationSetting parse(Object? raw) =>
      values.firstWhere((value) => value.name == raw, orElse: () => unknown);
}

/// iOS 가 앱에 알려주는 알림 설정 전부 (이슈 #237)
///
/// **진동 설정은 여기 없다** — iOS 는 손쉬운 사용·햅틱 설정을 앱에 주지 않는다.
/// 그것은 진동 시험으로 사용자에게 직접 묻는다.
class IosNotificationSettings {
  const IosNotificationSettings({
    required this.authorization,
    required this.lockScreen,
    required this.alert,
    required this.notificationCenter,
    required this.sound,
    required this.timeSensitive,
  });

  /// 읽지 못했을 때 — 모르는 것으로 경고하지 않는다
  static const unknown = IosNotificationSettings(
    authorization: IosNotificationAuthorization.unknown,
    lockScreen: IosNotificationSetting.unknown,
    alert: IosNotificationSetting.unknown,
    notificationCenter: IosNotificationSetting.unknown,
    sound: IosNotificationSetting.unknown,
    timeSensitive: IosNotificationSetting.unknown,
  );

  factory IosNotificationSettings.fromMap(Map<Object?, Object?>? raw) =>
      IosNotificationSettings(
        authorization: IosNotificationAuthorization.parse(
          raw?['authorization'],
        ),
        lockScreen: IosNotificationSetting.parse(raw?['lockScreen']),
        alert: IosNotificationSetting.parse(raw?['alert']),
        notificationCenter: IosNotificationSetting.parse(
          raw?['notificationCenter'],
        ),
        sound: IosNotificationSetting.parse(raw?['sound']),
        timeSensitive: IosNotificationSetting.parse(raw?['timeSensitive']),
      );

  final IosNotificationAuthorization authorization;

  /// 잠금 화면에 표시 — 꺼져 있으면 화면이 꺼진 채 도착했을 때 아무것도 안 보인다
  final IosNotificationSetting lockScreen;

  /// 배너 표시
  final IosNotificationSetting alert;
  final IosNotificationSetting notificationCenter;

  /// 소리 — 꺼지면 무음 파일로 붙인 시스템 진동도 함께 빠진다 (이슈 #221)
  final IosNotificationSetting sound;

  /// 시간 민감 알림 — 집중 모드를 뚫는다. 아직 권한(entitlement)이 없어 참고만 한다
  final IosNotificationSetting timeSensitive;

  /// 알림이 아예 막혔는가. 모르는 값(unknown)은 막힌 것으로 보지 않는다
  bool get isBlocked =>
      authorization == IosNotificationAuthorization.denied ||
      authorization == IosNotificationAuthorization.notDetermined;
}
