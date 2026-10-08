import CoreLocation
import Flutter
import Foundation

/// iOS 적응형 백그라운드 감시 (이슈 #231)
///
/// **영역 감시만으로는 부족했다.** 실기기에서 앱을 내리면 상태 막대의 위치 표시가
/// 사라져 사용자는 감시 중인지 알 수 없었고, 영역 이벤트는 늦거나 아예 오지 않았다
/// (300m 장소에 들어갔는데 콜백이 한 번도 오지 않았다).
///
/// 그래서 Android 하이브리드 감시(결정 024)처럼 **앱이 위치를 직접 받는다.** 다만
/// 내비게이션처럼 GPS 를 계속 켜지 않고, 가장 가까운 장소까지 거리에 따라 정확도를
/// 바꾼다. **단계를 고르는 것은 Dart(`WatchTierPolicy`) 한 곳이다** — 여기는 받은
/// 단계를 적용하고 측정을 넘기기만 한다.
///
/// - `showsBackgroundLocationIndicator` — 백그라운드에서도 상태 막대에 위치 표시가
///   남는다. 사용자가 "지금 감시 중"을 눈으로 확인하는 유일한 길이다.
/// - `startMonitoringSignificantLocationChanges` — 앱이 종료돼도 OS 가 다시 띄운다.
///   다시 뜨면 `restoreOnLaunch` 가 저장된 단계로 감시를 재개한다.
///   **사용자가 앱을 위로 쓸어 강제 종료하면 iOS 는 이것으로도 다시 띄우지 않는다**
///   — 그때는 영역 감시(native_geofence)가 남은 안전망이다.
///
/// **소리는 어떤 경우에도 여기서 내지 않는다** (CLAUDE.md 규칙 2). 위치만 다룬다.
final class AdaptiveLocationWatcher: NSObject, CLLocationManagerDelegate {
  static let shared = AdaptiveLocationWatcher()

  private static let channelName = "kr.suhsaechan.ear_loc_alert/ios_watch"
  private static let wantedKey = "ear_loc_alert.ios_watch.wanted"
  private static let tierKey = "ear_loc_alert.ios_watch.tier"

  /// 영역 감시·현재 위치 조회와 매니저를 나눈다 — 한쪽의 stop 이 다른 쪽을 끄지 않게
  private let manager = CLLocationManager()
  private var channel: FlutterMethodChannel?
  /// Dart 처리기가 붙었는가. 붙기 전 측정은 마지막 하나만 쥐고 있다가 넘긴다
  private var dartReady = false
  private var pendingFix: CLLocation?
  private var running = false

  /// 감시를 원하는가 — 재실행·권한 변경 후에도 이어가려고 저장한다
  private var wanted: Bool {
    get { UserDefaults.standard.bool(forKey: Self.wantedKey) }
    set { UserDefaults.standard.set(newValue, forKey: Self.wantedKey) }
  }

  private var tier: String {
    get { UserDefaults.standard.string(forKey: Self.tierKey) ?? "mid" }
    set { UserDefaults.standard.set(newValue, forKey: Self.tierKey) }
  }

  private override init() {
    super.init()
    manager.delegate = self
    // 멈춰 있다고 OS 가 갱신을 끊으면 다시 움직여도 깨어나지 못한다
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .other
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "attach":
        self.dartReady = true
        result(self.status())
        // 엔진이 뜨기 전에 받은 측정을 넘긴다 — 재실행 직후의 도착이 여기 있을 수 있다
        if let fix = self.pendingFix {
          self.pendingFix = nil
          self.send(fix)
        }
      case "start":
        if let requested = args?["tier"] as? String { self.tier = requested }
        self.wanted = true
        let (started, reason) = self.startIfAllowed(trigger: "dart")
        var payload = self.status()
        payload["started"] = started
        payload["reason"] = reason
        result(payload)
      case "setTier":
        if let requested = args?["tier"] as? String {
          self.tier = requested
          if self.running { self.apply(tier: requested) }
          NativeDiagnosticLog.write("watch", "tier applied tier=\(requested) running=\(self.running)")
        }
        result(nil)
      case "requestFix":
        // 장소가 바뀐 순간의 지금 위치 (이슈 #233). 움직이지 않으면 distanceFilter 에
        // 막혀 측정이 오지 않는다 — 갱신을 다시 시작하면 첫 측정을 곧바로 준다.
        // requestLocation 은 표준 갱신과 함께 쓰지 않는다(갱신 중 호출은 권장되지 않는다)
        let reason = args?["reason"] as? String ?? "unknown"
        if self.running {
          self.manager.stopUpdatingLocation()
          self.manager.startUpdatingLocation()
        }
        NativeDiagnosticLog.write("watch", "ios fix requested reason=\(reason) running=\(self.running)")
        result(nil)
      case "stop":
        self.wanted = false
        self.stopUpdates(reason: "dart")
        result(nil)
      case "status":
        result(self.status())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// 앱이 뜰 때마다 부른다. 감시를 원하던 상태면 Dart 를 기다리지 않고 바로 재개한다 —
  /// 백그라운드 재실행에서는 Flutter 첫 프레임이 오지 않아 Dart 부트스트랩이 늦다.
  func restoreOnLaunch(reason: String) {
    NativeDiagnosticLog.write(
      "watch",
      "ios watch launch reason=\(reason) wanted=\(wanted) tier=\(tier) auth=\(Self.authName(manager.authorizationStatus))"
    )
    if wanted { _ = startIfAllowed(trigger: "launch") }
  }

  private func startIfAllowed(trigger: String) -> (Bool, String?) {
    // "항상" 이 아니면 백그라운드에서 갱신을 받을 수 없다 — 영역 감시만 남는다
    guard manager.authorizationStatus == .authorizedAlways else {
      if running { stopUpdates(reason: "not_always") }
      let auth = Self.authName(manager.authorizationStatus)
      NativeDiagnosticLog.write("watch", "ios watch not started trigger=\(trigger) reason=not_always auth=\(auth)")
      return (false, "not_always")
    }
    apply(tier: tier)
    if !running {
      // 반드시 시작 전에 켠다 — UIBackgroundModes 에 location 이 있어야 크래시하지 않는다
      manager.allowsBackgroundLocationUpdates = true
      manager.showsBackgroundLocationIndicator = true
      manager.startUpdatingLocation()
      manager.startMonitoringSignificantLocationChanges()
      running = true
      NativeDiagnosticLog.write("watch", "ios watch started trigger=\(trigger) tier=\(tier)")
    }
    return (true, nil)
  }

  private func stopUpdates(reason: String) {
    guard running else { return }
    manager.stopUpdatingLocation()
    manager.stopMonitoringSignificantLocationChanges()
    // 끄지 않으면 감시할 장소가 없는데도 위치 표시가 남는다
    manager.allowsBackgroundLocationUpdates = false
    running = false
    NativeDiagnosticLog.write("watch", "ios watch stopped reason=\(reason)")
  }

  /// 단계별 설정. 값의 근거는 docs/10-DECISIONS.md 054
  private func apply(tier: String) {
    switch tier {
    case "far":
      manager.desiredAccuracy = kCLLocationAccuracyKilometer
      manager.distanceFilter = 500
    case "precise":
      manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      manager.distanceFilter = 10
    default:
      manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
      manager.distanceFilter = 100
    }
  }

  private func status() -> [String: Any] {
    [
      "running": running,
      "wanted": wanted,
      "tier": tier,
      "authorization": Self.authName(manager.authorizationStatus),
    ]
  }

  private func send(_ location: CLLocation) {
    channel?.invokeMethod("onLocation", arguments: [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracyMeters": location.horizontalAccuracy,
      "timestampMs": Int64(location.timestamp.timeIntervalSince1970 * 1000),
    ])
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 음수 정확도는 무효 측정이다. 묶여 오면 가장 최근 것만 쓴다 — 판정은 지금 위치로 한다
    guard let latest = locations.last(where: { $0.horizontalAccuracy >= 0 }) else { return }
    if dartReady {
      send(latest)
    } else {
      pendingFix = latest
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // locationUnknown 은 "아직 모른다"는 일시 상태다 — 계속 기다린다
    if let clError = error as? CLError, clError.code == .locationUnknown { return }
    NativeDiagnosticLog.write("watch", "ios watch location error=\(error.localizedDescription)")
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let auth = Self.authName(manager.authorizationStatus)
    NativeDiagnosticLog.write("watch", "authorization changed auth=\(auth) wanted=\(wanted) running=\(running)")
    guard wanted else { return }
    // 설정에서 "항상"으로 올리면 그 자리에서 시작하고, 내리면 멈춘다 (원하는 상태는 남긴다)
    _ = startIfAllowed(trigger: "authorization")
  }

  private static func authName(_ status: CLAuthorizationStatus) -> String {
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
