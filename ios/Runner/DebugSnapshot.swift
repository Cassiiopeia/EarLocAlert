import CoreLocation
import Flutter
import UIKit
import UserNotifications

/// 진단 보고서용 네이티브 상태 전체 (이슈 #290)
/// 구역 7개: 기기, 배터리, 백그라운드, 위치, 적응형 감시, 위치 서비스, 알림 대기열
///
/// 채널 계약 (`kr.suhsaechan.ear_loc_alert/app_config`, Android `MainActivity` 와 같은 이름):
/// - `versionLabel` → `1.37.1(90151)`
/// - `deviceInfo` → `model=iPhone15,2 ios=18.1 ...` 한 줄
/// - `debugSnapshot` → 구역별 여러 줄 텍스트
/// 그 외(`isDevBuild` 등)는 미구현 — Dart 가 기본값으로 떨어진다
enum DebugSnapshot {
  private static let channelName = "kr.suhsaechan.ear_loc_alert/app_config"

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "versionLabel": result(versionLabel())
        case "deviceInfo": result(deviceInfo())
        case "debugSnapshot": collect { text in result(text) }
        default: result(FlutterMethodNotImplemented)
        }
      }
  }

  /// 구역 전체 수집 > 알림 대기열(비동기)까지 모아 메인 스레드에서 한 번 응답
  static func collect(completion: @escaping (String) -> Void) {
    var lines: [String] = []
    lines += ["[device]", deviceInfo()]
    lines += ["[battery]"] + battery()
    lines += ["[background]"] + background()
    lines += ["[location]"] + location()
    lines += ["[ios_watch]"] + iosWatch()

    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { pending in
      center.getDeliveredNotifications { delivered in
        // 메인 스레드에서 부르면 UI 가 멈출 수 있는 조회라 완료 처리기(백그라운드)에서 읽는다
        var queue = ["[location_services]", "enabled=\(CLLocationManager.locationServicesEnabled())"]
        queue += ["[notifications]", "pending=\(pending.count) delivered=\(delivered.count)"]
        queue += pending.map { "  pending id=\($0.identifier) trigger=\(triggerName($0.trigger))" }
        queue += delivered.map { "  delivered id=\($0.request.identifier) at=\(iso($0.date))" }
        DispatchQueue.main.async { completion((lines + queue).joined(separator: "\n")) }
      }
    }
  }

  static func versionLabel() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(version)(\(build))"
  }

  /// 기기·앱 기본 정보 한 줄 (Android `DeviceInfo.summary` 와 같은 결, 기기 식별자 제외)
  static func deviceInfo() -> String {
    let device = UIDevice.current
    let process = ProcessInfo.processInfo
    return [
      "model=\(modelIdentifier())",
      "ios=\(device.systemVersion)",
      "app=\(versionLabel())",
      "locale=\(Locale.current.identifier)",
      "tz=\(TimeZone.current.identifier)",
      "low_power=\(process.isLowPowerModeEnabled)",
      "thermal=\(thermalName(process.thermalState))",
      "ram_mb=\(process.physicalMemory / (1024 * 1024))",
    ].joined(separator: " ")
  }

  /// 배터리 잔량·충전 상태 (조회 동안만 모니터링 켬)
  private static func battery() -> [String] {
    let device = UIDevice.current
    let wasMonitoring = device.isBatteryMonitoringEnabled
    device.isBatteryMonitoringEnabled = true
    defer { device.isBatteryMonitoringEnabled = wasMonitoring }
    let level = device.batteryLevel < 0 ? "?" : "\(Int(device.batteryLevel * 100))%"
    return ["level=\(level) state=\(batteryStateName(device.batteryState))"]
  }

  /// 앱 상태·백그라운드 새로고침 (꺼져 있으면 재실행 경로가 막힌다)
  private static func background() -> [String] {
    let app = UIApplication.shared
    return [
      "app_state=\(applicationStateName(app.applicationState))",
      "background_refresh=\(refreshName(app.backgroundRefreshStatus))",
      "protected_data=\(app.isProtectedDataAvailable)",
    ]
  }

  /// 위치 권한·정확도·OS 에 등록된 영역 전체
  private static func location() -> [String] {
    let manager = CLLocationManager()
    var lines = [
      "authorization=\(authorizationName(manager.authorizationStatus))",
      "accuracy=\(manager.accuracyAuthorization == .fullAccuracy ? "full" : "reduced")",
      "significant_change=\(CLLocationManager.significantLocationChangeMonitoringAvailable())",
      "monitored_regions=\(manager.monitoredRegions.count)",
    ]
    lines += manager.monitoredRegions
      .sorted { $0.identifier < $1.identifier }
      .map { region in
        guard let circle = region as? CLCircularRegion else { return "  region id=\(region.identifier)" }
        return "  region id=\(circle.identifier) lat=\(circle.center.latitude) "
          + "lng=\(circle.center.longitude) radius=\(Int(circle.radius))m "
          + "entry=\(circle.notifyOnEntry) exit=\(circle.notifyOnExit)"
      }
    return lines
  }

  private static func iosWatch() -> [String] {
    AdaptiveLocationWatcher.shared.status()
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
  }

  /// `iPhone15,2` 형태 기종 식별자 (시뮬레이터는 환경변수 값)
  private static func modelIdentifier() -> String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return "\(simulated)(simulator)"
    }
    var system = utsname()
    uname(&system)
    return withUnsafeBytes(of: &system.machine) { buffer in
      String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    }
  }

  private static func iso(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }

  private static func triggerName(_ trigger: UNNotificationTrigger?) -> String {
    switch trigger {
    case let interval as UNTimeIntervalNotificationTrigger: return "interval(\(Int(interval.timeInterval))s)"
    case is UNCalendarNotificationTrigger: return "calendar"
    case is UNLocationNotificationTrigger: return "location"
    case nil: return "immediate"
    default: return "other"
    }
  }

  private static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
  }

  private static func batteryStateName(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .unplugged: return "unplugged"
    case .charging: return "charging"
    case .full: return "full"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }

  private static func applicationStateName(_ state: UIApplication.State) -> String {
    switch state {
    case .active: return "active"
    case .inactive: return "inactive"
    case .background: return "background"
    @unknown default: return "unknown"
    }
  }

  private static func refreshName(_ status: UIBackgroundRefreshStatus) -> String {
    switch status {
    case .available: return "available"
    case .denied: return "denied"
    case .restricted: return "restricted"
    @unknown default: return "unknown"
    }
  }

  private static func authorizationName(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "when_in_use"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    @unknown default: return "unknown"
    }
  }
}
