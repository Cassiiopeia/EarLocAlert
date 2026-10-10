import 'package:ear_loc_alert/app/background/arrival_alarm_channel.dart';
import 'package:ear_loc_alert/app/home_status_provider.dart';
import 'package:ear_loc_alert/app/ios_alert_readiness.dart';
import 'package:ear_loc_alert/features/alert/domain/vibration_check.dart';
import 'package:ear_loc_alert/features/permission/domain/ios_notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

IosNotificationSettings _settings({
  IosNotificationAuthorization auth = IosNotificationAuthorization.authorized,
  IosNotificationSetting lockScreen = IosNotificationSetting.enabled,
  IosNotificationSetting timeSensitive = IosNotificationSetting.enabled,
  IosNotificationSetting alert = IosNotificationSetting.enabled,
}) => IosNotificationSettings(
  authorization: auth,
  lockScreen: lockScreen,
  alert: alert,
  notificationCenter: IosNotificationSetting.enabled,
  sound: IosNotificationSetting.enabled,
  timeSensitive: timeSensitive,
);

const _alarmOn = ArrivalAlarmStatus(
  supported: true,
  authorization: ArrivalAlarmAuthorization.authorized,
);

/// 진동을 느꼈다고 답한 상태 — 다른 항목만 보는 테스트가 진동 항목에 흔들리지 않게 한다
final _felt = VibrationCheckResult(felt: true, answeredAt: DateTime.utc(2026));

/// iOS 알림 설정 → 홈 경고 항목 (이슈 #237)
///
/// **막는 것만 올린다.** 사용자가 바로 고칠 수 있고, 고치지 않으면 도착이 그냥
/// 지나가는 것만. 모르는 값으로 경고하지 않는다 (#142 QA).
void main() {
  test('모두 켜져 있으면 비어 있다', () {
    expect(
      iosAlertGaps(
        notifications: _settings(),
        alarm: _alarmOn,
        vibration: VibrationCheckResult(
          felt: true,
          answeredAt: DateTime.utc(2026),
        ),
      ),
      isEmpty,
    );
  });

  test('알림 설정을 읽지 못해도 그것만으로 경고하지 않는다 — 진동 확인만 남는다', () {
    final felt = VibrationCheckResult(
      felt: true,
      answeredAt: DateTime.utc(2026),
    );
    expect(
      iosAlertGaps(notifications: null, alarm: null, vibration: felt),
      isEmpty,
    );
    expect(
      iosAlertGaps(
        notifications: IosNotificationSettings.unknown,
        alarm: ArrivalAlarmStatus.unsupported,
        vibration: felt,
      ),
      isEmpty,
    );
  });

  test('진동 시험을 아직 안 했으면 진동 확인을 올린다 (이슈 #250)', () {
    expect(
      iosAlertGaps(
        notifications: _settings(),
        alarm: _alarmOn,
        vibration: null,
      ),
      [ReliabilityGap.vibration],
    );
  });

  test('알림이 거부되면 알림 항목만 — 잠금 화면을 겹쳐 올리지 않는다', () {
    expect(
      iosAlertGaps(
        notifications: _settings(
          auth: IosNotificationAuthorization.denied,
          lockScreen: IosNotificationSetting.disabled,
        ),
        alarm: _alarmOn,
        vibration: _felt,
      ),
      [ReliabilityGap.notifications],
    );
  });

  test('잠금 화면 표시가 꺼지면 막힌 것이다', () {
    expect(
      iosAlertGaps(
        notifications: _settings(lockScreen: IosNotificationSetting.disabled),
        alarm: _alarmOn,
        vibration: _felt,
      ),
      [ReliabilityGap.lockScreen],
    );
  });

  test('시간 민감·배너가 꺼진 것은 막지 않는다 — 기록만 한다', () {
    expect(
      iosAlertGaps(
        notifications: _settings(
          timeSensitive: IosNotificationSetting.disabled,
          alert: IosNotificationSetting.disabled,
        ),
        alarm: _alarmOn,
        vibration: _felt,
      ),
      isEmpty,
    );
  });

  test('잠금 화면 알람은 지원하는 기기에서 거부했을 때만 막힌 것이다', () {
    List<ReliabilityGap> gapsFor(ArrivalAlarmStatus alarm) => iosAlertGaps(
      notifications: _settings(),
      alarm: alarm,
      vibration: _felt,
    );

    expect(
      gapsFor(
        const ArrivalAlarmStatus(
          supported: true,
          authorization: ArrivalAlarmAuthorization.denied,
        ),
      ),
      [ReliabilityGap.lockScreenAlarm],
    );
    // 아직 묻지 않았으면 물을 기회가 남아 있다
    expect(
      gapsFor(
        const ArrivalAlarmStatus(
          supported: true,
          authorization: ArrivalAlarmAuthorization.notDetermined,
        ),
      ),
      isEmpty,
    );
    // iOS 26 미만에는 켤 것이 없다
    expect(gapsFor(ArrivalAlarmStatus.unsupported), isEmpty);
  });

  test('진동 시험에서 "아니요"면 다음에 "예"라고 답할 때까지 막힌 것이다', () {
    List<ReliabilityGap> gapsFor(bool? felt) => iosAlertGaps(
      notifications: _settings(),
      alarm: _alarmOn,
      vibration: felt == null
          ? null
          : VibrationCheckResult(felt: felt, answeredAt: DateTime.utc(2026)),
    );

    expect(gapsFor(false), [ReliabilityGap.vibration]);
    expect(gapsFor(true), isEmpty);
    // 시험하지 않은 사용자에게도 확인을 권한다 (이슈 #250) — 설정을 앱이 못 읽는다
    expect(gapsFor(null), [ReliabilityGap.vibration]);
  });

  test('네이티브 문자열을 읽는다 — 모르는 문자열은 unknown', () {
    final parsed = IosNotificationSettings.fromMap({
      'authorization': 'denied',
      'lockScreen': 'disabled',
      'alert': 'enabled',
      'notificationCenter': 'notSupported',
      'sound': 'something-new',
    });
    expect(parsed.authorization, IosNotificationAuthorization.denied);
    expect(parsed.lockScreen, IosNotificationSetting.disabled);
    expect(parsed.notificationCenter, IosNotificationSetting.notSupported);
    expect(parsed.sound, IosNotificationSetting.unknown);
    expect(parsed.timeSensitive, IosNotificationSetting.unknown);
    expect(parsed.isBlocked, isTrue);
  });

  test('설정 앱에서 고치는 항목과 안내 시트로 가는 항목을 가른다', () {
    expect(ReliabilityGap.notifications.fixedInSystemSettings, isTrue);
    expect(ReliabilityGap.lockScreen.fixedInSystemSettings, isTrue);
    expect(ReliabilityGap.lockScreenAlarm.fixedInSystemSettings, isTrue);
    expect(ReliabilityGap.vibration.fixedInSystemSettings, isFalse);
  });
}
