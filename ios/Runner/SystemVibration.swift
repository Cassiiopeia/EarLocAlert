import AudioToolbox
import Flutter
import Foundation

/// 백그라운드 세션용 시스템 진동 (이슈 #235)
///
/// `vibration` 플러그인은 iPhone 에서 Core Haptics 로 떤다. Core Haptics 는 앱이
/// 백그라운드에 있으면 재생되지 않는다 — 실기기에서 세션은 돌았는데 앱을 열 때까지
/// 한 번도 떨지 않았다. `kSystemSoundID_Vibrate` 는 백그라운드에서도 진동한다.
///
/// **진동만 한다.** `kSystemSoundID_Vibrate` 는 소리 없는 진동 전용 ID 다 —
/// 네이티브에서 소리를 내지 않는 규칙(CLAUDE.md 규칙 2)과 부딪히지 않는다.
/// 세기·길이는 조절할 수 없다 — 앱이 전면이면 Dart 가 햅틱으로 되돌린다.
enum SystemVibration {
  private static let channelName = "kr.suhsaechan.ear_loc_alert/system_vibration"

  /// 첫 진동만 남긴다 — 3초마다 남기면 진단 기록이 진동 줄로 덮인다
  private static var firstPulseLogged = false

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "vibrate" else {
          result(FlutterMethodNotImplemented)
          return
        }
        AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)
        if !firstPulseLogged {
          firstPulseLogged = true
          NativeDiagnosticLog.write("alert", "system vibration first pulse")
        }
        result(nil)
      }
  }
}
