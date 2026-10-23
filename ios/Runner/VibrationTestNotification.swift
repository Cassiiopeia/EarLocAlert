import Flutter
import Foundation
import UIKit
import UserNotifications

/// 진동 점검용 시험 알림 (이슈 #301)
///
/// **실제 도착 알림과 같은 무음 알림음으로 보낸다.** 앱 화면 햅틱으로 시험하면 iPhone 의
/// 햅틱 설정이 꺼져 있어도 떨려서 "느꼈다"가 나왔다. 화면이 꺼진 채 알림으로 떨어 봐야
/// 실제 도착과 같은 설정(햅틱·손쉬운 사용 진동·집중 모드)을 거친다.
///
/// **OS 가 정해진 시각에 보낸다** (`UNTimeIntervalNotificationTrigger`). 사용자가 화면을
/// 잠그면 앱이 멈출 수 있어 Dart 타이머로는 보장되지 않는다.
///
/// 채널 계약 (`kr.suhsaechan.ear_loc_alert/vibration_test_notification`):
/// - `schedule` `{title, body, delaySeconds}` → `true` 예약됨 / `false` 실패
/// - `cancel` → 대기·표시 중인 시험 알림 제거
/// - `openNotificationSettings` → 설정 > 알림 > 이 앱 (iOS 16 미만은 이 앱 설정 페이지)
enum VibrationTestNotification {
  private static let channelName = "kr.suhsaechan.ear_loc_alert/vibration_test_notification"
  private static let identifier = "ear_loc_alert.vibration_test"
  /// 도착 알림과 같은 파일 — Dart `iosSilentHapticSound` 와 같은 값
  private static let silentHapticSoundName = "silent_haptic.caf"

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "schedule":
          schedule(
            title: args?["title"] as? String ?? "",
            body: args?["body"] as? String ?? "",
            delaySeconds: args?["delaySeconds"] as? Double ?? 5,
            result: result
          )
        case "cancel":
          cancel()
          result(nil)
        case "openNotificationSettings":
          openNotificationSettings(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private static func schedule(
    title: String,
    body: String,
    delaySeconds: Double,
    result: @escaping FlutterResult
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    // 무음 파일을 소리로 지정해야 진동이 붙는다 — 들리는 소리는 없다 (CLAUDE.md 규칙 2)
    content.sound = UNNotificationSound(named: UNNotificationSoundName(silentHapticSoundName))
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }
    // 트리거 최소값 0 초과 — 0 이하를 넘기면 예외
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    // 지난 시험 알림 정리 후 예약 (다시 보내기에서 두 개가 쌓이지 않게)
    cancel()
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        NativeDiagnosticLog.write("vibration", "test notification schedule failed error=\(error.localizedDescription)")
      } else {
        NativeDiagnosticLog.write("vibration", "test notification scheduled delay=\(delaySeconds)")
      }
      DispatchQueue.main.async { result(error == nil) }
    }
  }

  private static func cancel() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
  }

  private static func openNotificationSettings(result: @escaping FlutterResult) {
    var urlString = UIApplication.openSettingsURLString
    if #available(iOS 16.0, *) {
      urlString = UIApplication.openNotificationSettingsURLString
    }
    guard let url = URL(string: urlString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url) { opened in
      NativeDiagnosticLog.write("vibration", "notification settings opened=\(opened)")
      result(opened)
    }
  }
}
