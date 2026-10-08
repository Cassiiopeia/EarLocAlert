import Flutter
import Foundation
import UserNotifications

/// iOS 알림 설정 읽기 (이슈 #237)
///
/// **진동 설정은 읽을 수 없지만 알림 설정은 읽을 수 있다.** 사용자가 잠금 화면 표시를
/// 끄면 화면이 꺼진 채 도착했을 때 아무것도 보이지 않는데, 앱은 그것을 몰라 계속
/// "감시 중"이라고 말했다. 읽을 수 있는 것은 전부 읽어 홈 경고에 올린다.
///
/// `flutter_local_notifications` 의 `checkPermissions` 는 잠금 화면·알림 센터·
/// 시간 민감 값을 주지 않아 직접 읽는다.
///
/// 채널 계약 (`kr.suhsaechan.ear_loc_alert/notification_settings`):
/// - `read` → `{authorization, lockScreen, alert, notificationCenter, sound, timeSensitive}`
///   authorization 은 `notDetermined|denied|authorized|provisional|ephemeral|unknown`,
///   나머지는 `enabled|disabled|notSupported|unknown`
enum NotificationSettingsReader {
  private static let channelName = "kr.suhsaechan.ear_loc_alert/notification_settings"

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "read" else {
          result(FlutterMethodNotImplemented)
          return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          var payload: [String: String] = [
            "authorization": authorization(settings.authorizationStatus),
            "lockScreen": setting(settings.lockScreenSetting),
            "alert": setting(settings.alertSetting),
            "notificationCenter": setting(settings.notificationCenterSetting),
            "sound": setting(settings.soundSetting),
            // iOS 15 미만에는 시간 민감 알림 개념이 없다
            "timeSensitive": "notSupported",
          ]
          if #available(iOS 15.0, *) {
            payload["timeSensitive"] = setting(settings.timeSensitiveSetting)
          }
          // 완료 처리기는 임의 스레드에서 온다 — 채널 응답은 메인 스레드에서 한다
          DispatchQueue.main.async { result(payload) }
        }
      }
  }

  private static func authorization(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }

  private static func setting(_ value: UNNotificationSetting) -> String {
    switch value {
    case .enabled: return "enabled"
    case .disabled: return "disabled"
    case .notSupported: return "notSupported"
    @unknown default: return "unknown"
    }
  }
}
