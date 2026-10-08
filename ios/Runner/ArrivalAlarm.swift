import Flutter
import Foundation
import UIKit

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import SwiftUI
#endif

/// 잠금 화면 전체를 덮는 도착 알람 (이슈 #235, 결정 057)
///
/// **화면이 꺼진 iPhone 에서는 알림 한 줄과 진동뿐이었다.** 주머니 속에서는 그
/// 진동을 놓치고, 화면을 켜도 알림 화면이 아니라 잠금 화면이 보였다. iOS 26 의
/// AlarmKit 은 시계 앱 알람처럼 잠금 화면 전체를 덮는다 — 그것을 빌린다.
///
/// **알람음은 무음 파일(`silent_haptic.caf`)이다.** AlarmKit 알람은 스피커로
/// 울리므로, 소리를 넣는 순간 이어폰 허용 목록 판정(CLAUDE.md 규칙 2)을 우회한다.
/// 소리는 여전히 Dart `AlertController` 가 이어폰일 때만 낸다. 여기서는 화면만 덮는다.
///
/// 로컬 Xcode(16.x)에는 AlarmKit 이 없다 — `canImport` 로 막아 두어 로컬 빌드는
/// "지원 안 함" 경로만 컴파일된다. AlarmKit 경로는 Xcode 26 CI 에서만 컴파일된다.
///
/// 채널 계약 (`kr.suhsaechan.ear_loc_alert/arrival_alarm`):
/// - `status` → `{supported, authorization}` — authorization 은
///   `notDetermined|denied|authorized|unsupported`
/// - `requestAuthorization` → 요청 뒤의 authorization 문자열
/// - `present {title, stopLabel}` → 예약한 알람 id 문자열
/// - `stopAll` → 이 앱이 띄운 알람을 모두 끈다
/// - `openSettings` → 앱 설정 화면을 연다 (거부된 뒤 다시 켜는 길)
/// - 네이티브 → Dart `onAlarmStopped {id}` — 사용자가 잠금 화면에서 알람을 껐다
final class ArrivalAlarm {
  static let shared = ArrivalAlarm()

  private static let channelName = "kr.suhsaechan.ear_loc_alert/arrival_alarm"

  private var channel: FlutterMethodChannel?

  /// iOS 26 이상에서만 채워진다. 타입을 `Any` 로 두는 것은 저장 프로퍼티에
  /// `@available` 을 붙일 수 없어서다
  private var bridge: Any?

  private init() {}

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    makeBridgeIfAvailable()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "status":
        result(self.status())
      case "requestAuthorization":
        self.requestAuthorization(result)
      case "present":
        let args = call.arguments as? [String: Any]
        let title = args?["title"] as? String ?? ""
        let stopLabel = args?["stopLabel"] as? String ?? "Stop"
        self.present(title: title, stopLabel: stopLabel, result: result)
      case "stopAll":
        self.stopAll(reason: (call.arguments as? [String: Any])?["reason"] as? String ?? "dart")
        result(nil)
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func makeBridgeIfAvailable() {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      bridge = ArrivalAlarmKitBridge { [weak self] id in
        // 사용자가 잠금 화면에서 껐다 — Dart 가 세션(진동·이어폰 소리)을 끈다
        self?.channel?.invokeMethod("onAlarmStopped", arguments: ["id": id.uuidString])
      }
    }
    #endif
  }

  private func status() -> [String: Any] {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *), let bridge = bridge as? ArrivalAlarmKitBridge {
      return ["supported": true, "authorization": bridge.authorization()]
    }
    #endif
    return ["supported": false, "authorization": "unsupported"]
  }

  private func requestAuthorization(_ result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *), let bridge = bridge as? ArrivalAlarmKitBridge {
      bridge.requestAuthorization { result($0) }
      return
    }
    #endif
    result("unsupported")
  }

  private func present(title: String, stopLabel: String, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *), let bridge = bridge as? ArrivalAlarmKitBridge {
      bridge.present(title: title, stopLabel: stopLabel) { outcome in
        switch outcome {
        case .success(let id):
          result(id.uuidString)
        case .failure(let error):
          NativeDiagnosticLog.write("alarm", "schedule failed error=\(error)")
          result(FlutterError(code: "schedule_failed", message: "\(error)", details: nil))
        }
      }
      return
    }
    #endif
    result(FlutterError(code: "unsupported", message: nil, details: nil))
  }

  private func stopAll(reason: String) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *), let bridge = bridge as? ArrivalAlarmKitBridge {
      bridge.stopAll(reason: reason)
    }
    #endif
  }
}

#if canImport(AlarmKit)

/// 알람에 붙는 부가 정보 — 지금은 쓸 것이 없지만 `AlarmAttributes` 가 타입을 요구한다
@available(iOS 26.0, *)
struct ArrivalAlarmMetadata: AlarmMetadata {}

/// AlarmKit 호출을 한곳에 모은다 (iOS 26+)
///
/// 상태는 메인 스레드에서만 만진다 — 채널 호출은 메인에서 오고, 비동기 결과와
/// 갱신 관찰은 `@MainActor` Task 로 돌려 같은 줄에 세운다.
@available(iOS 26.0, *)
final class ArrivalAlarmKitBridge {
  private let manager = AlarmManager.shared
  private let onStopped: (UUID) -> Void

  /// 이 앱이 띄웠고 아직 끝나지 않은 알람
  private var presented = Set<UUID>()

  /// 갱신 목록에서 한 번이라도 본 알람. 예약 직후 목록에 아직 없는 것을
  /// "꺼졌다"로 읽지 않으려고 둔다
  private var seen = Set<UUID>()

  /// 상태 전이 기록용 — 바뀔 때만 남긴다
  private var lastState: [UUID: String] = [:]

  private var observer: Task<Void, Never>?

  init(onStopped: @escaping (UUID) -> Void) {
    self.onStopped = onStopped
    observer = Task { @MainActor [weak self] in
      for await alarms in AlarmManager.shared.alarmUpdates {
        self?.handle(alarms)
      }
    }
  }

  func authorization() -> String {
    Self.name(manager.authorizationState)
  }

  func requestAuthorization(_ completion: @escaping (String) -> Void) {
    Task { @MainActor in
      do {
        let state = try await AlarmManager.shared.requestAuthorization()
        let name = Self.name(state)
        NativeDiagnosticLog.write("alarm", "authorization requested result=\(name)")
        completion(name)
      } catch {
        NativeDiagnosticLog.write("alarm", "authorization request failed error=\(error)")
        completion(Self.name(AlarmManager.shared.authorizationState))
      }
    }
  }

  /// 곧바로(1초 뒤) 울리는 일회성 알람을 건다. 카운트다운 표시가 없으니
  /// 위젯 확장 없이 잠금 화면 알람만 뜬다.
  func present(
    title: String,
    stopLabel: String,
    completion: @escaping (Result<UUID, Error>) -> Void
  ) {
    // 런타임 문자열을 그대로 쓴다 — 키로 찾지 못하면 그 문자열이 보인다.
    // 번역은 Dart 가 앱 언어로 해서 넘긴다
    let stopButton = AlarmButton(
      text: LocalizedStringResource(String.LocalizationValue(stopLabel)),
      textColor: .white,
      systemImageName: "stop.circle"
    )
    // iOS 26.0 SDK(CI 의 Xcode 26.0)에는 stopButton 을 받는 생성자만 있다.
    // 26.1 에서 deprecated 됐지만 그 SDK 로 빌드해도 경고일 뿐이다
    let alert = AlarmPresentation.Alert(
      title: LocalizedStringResource(String.LocalizationValue(title)),
      stopButton: stopButton
    )
    let attributes = AlarmAttributes<ArrivalAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: ArrivalAlarmMetadata(),
      tintColor: .orange
    )
    // 무음 파일 — 스피커로 새지 않게 한다 (CLAUDE.md 규칙 2, 결정 057)
    let configuration = AlarmManager.AlarmConfiguration<ArrivalAlarmMetadata>.alarm(
      schedule: .fixed(Date().addingTimeInterval(1)),
      attributes: attributes,
      sound: .named("silent_haptic.caf")
    )

    let id = UUID()
    presented.insert(id)
    Task { @MainActor [weak self] in
      do {
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        NativeDiagnosticLog.write("alarm", "scheduled id=\(id.uuidString)")
        completion(.success(id))
      } catch {
        self?.presented.remove(id)
        completion(.failure(error))
      }
    }
  }

  /// 이 앱의 알람을 모두 끈다. 먼저 집합에서 빼므로 그 뒤 갱신이 와도
  /// "사용자가 껐다"로 Dart 에 알리지 않는다 — 세션을 두 번 끄지 않게 한다
  func stopAll(reason: String) {
    var ids = presented
    // 지난 실행이 남긴 알람도 끈다 — 집합은 프로세스와 함께 사라진다
    if let all = try? manager.alarms {
      ids.formUnion(all.map(\.id))
    }
    presented.removeAll()
    seen.removeAll()
    lastState.removeAll()
    guard !ids.isEmpty else { return }
    for id in ids {
      // 울리는 중이면 stop, 아직 예약 상태면 cancel 이 맞다 — 어느 쪽인지 따지지 않고 둘 다 시도한다
      try? manager.stop(id: id)
      try? manager.cancel(id: id)
    }
    NativeDiagnosticLog.write("alarm", "stopped all count=\(ids.count) reason=\(reason)")
  }

  private func handle(_ alarms: [Alarm]) {
    let current = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    for id in presented {
      if let alarm = current[id] {
        seen.insert(id)
        let state = Self.name(alarm.state)
        if lastState[id] != state {
          lastState[id] = state
          NativeDiagnosticLog.write("alarm", "state id=\(id.uuidString) state=\(state)")
        }
      } else if seen.contains(id) {
        // 목록에서 사라졌다 — 일회성 알람은 꺼지는 순간 지워진다 (AlarmManager.alarms 문서)
        presented.remove(id)
        seen.remove(id)
        lastState.removeValue(forKey: id)
        NativeDiagnosticLog.write("alarm", "stop observed id=\(id.uuidString)")
        onStopped(id)
      }
    }
  }

  private static func name(_ state: AlarmManager.AuthorizationState) -> String {
    switch state {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    @unknown default: return "notDetermined"
    }
  }

  private static func name(_ state: Alarm.State) -> String {
    switch state {
    case .scheduled: return "scheduled"
    case .countdown: return "countdown"
    case .paused: return "paused"
    case .alerting: return "alerting"
    @unknown default: return "unknown"
    }
  }
}

#endif
