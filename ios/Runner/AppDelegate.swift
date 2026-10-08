import Flutter
import UIKit
import CoreLocation
import GoogleMaps
import UserNotifications
import flutter_local_notifications
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate {
  // CLLocationManager 는 조회가 끝날 때까지 살아 있어야 해서 앱 수명만큼 들고 있다
  private let currentLocation = CurrentLocationProvider()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps (docs/08-OPERATIONS.md).
    //
    // 키는 Info.plist → MapsKey.xcconfig → .env 순으로 거슬러 올라간다.
    // **키가 비어 있어도 SDK 는 반드시 켠다 (이슈 #191).** 켜지 않은 채 지도 뷰를
    // 만들면 SDK 가 예외를 던져 홈 화면 진입 순간 앱이 종료된다. 반대로 빈 문자열을
    // 넘겨도 예외가 난다. 그래서 비면 자리표시 문자열을 넘긴다 — 지도는 빈 화면으로
    // 뜨지만 앱은 죽지 않는다. 배포 빌드는 CI 가 빈 키를 막는다.
    let mapsApiKey = (Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String) ?? ""
    GMSServices.provideAPIKey(mapsApiKey.isEmpty ? "MISSING_MAPS_API_KEY" : mapsApiKey)

    // native_geofence — 백그라운드 isolate 에서도 플러그인(drift·알림 등)을
    // 쓸 수 있게 등록 콜백을 넘긴다 (이슈 #63)
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }
    // 알림의 "알림 끄기" 버튼 (이슈 #237) — 앱을 띄우지 않는 버튼은 플러그인이 별도
    // 헤드리스 엔진에서 처리한다. 그 엔진도 플러그인(SharedPreferences·알림)을 써야
    // 대기 알림을 지우고 알림을 걷을 수 있다. 등록하지 않으면 버튼을 누르는 순간 죽는다
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }

    // 알림 응답(버튼 탭)이 플러그인까지 오려면 앱이 알림 센터의 delegate 여야 한다
    // (이슈 #237). FlutterAppDelegate 가 받아 플러그인에 넘긴다 — 지금까지는 아무도
    // 설정하지 않아 버튼을 달아도 눌림이 앱에 닿지 않았다
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)

    // Google Maps API 키를 Dart(장소 검색 REST)에 넘긴다.
    // 키의 단일 소스는 .env → Info.plist 주입이고, 여기서는 그 값을
    // 도로 읽기만 한다 (docs/08-OPERATIONS.md).
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: "kr.suhsaechan.ear_loc_alert/maps_api_key",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        guard call.method == "getMapsApiKey" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String ?? "")
      }

      // 지도 "내 위치" 버튼용 현재 위치 1회 조회 (이슈 #213).
      // Android 에만 있던 채널이라 iOS 에서는 권한이 있어도 항상 실패했다.
      FlutterMethodChannel(
        name: "kr.suhsaechan.ear_loc_alert/current_location",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "getCurrentLocation" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.currentLocation.fetch(result)
      }

      // 적응형 백그라운드 감시 (이슈 #231)
      AdaptiveLocationWatcher.shared.register(messenger: controller.binaryMessenger)

      // 백그라운드 세션의 진동 (이슈 #235) — Core Haptics 는 백그라운드에서 멈춘다
      SystemVibration.register(messenger: controller.binaryMessenger)

      // 잠금 화면 전체를 덮는 무음 알람 (이슈 #235, iOS 26+). 그 미만은 "지원 안 함"만 답한다
      ArrivalAlarm.shared.register(messenger: controller.binaryMessenger)

      // 읽을 수 있는 알림 설정(잠금 화면 표시 등)을 홈 경고에 올린다 (이슈 #237)
      NotificationSettingsReader.register(messenger: controller.binaryMessenger)
    }

    // 위치 사유로 다시 떴든(중요 위치 변화·영역 이벤트) 사용자가 열었든, 감시를 원하던
    // 상태면 Dart 를 기다리지 않고 재개한다 — 백그라운드 재실행은 첫 프레임이 없어
    // Dart 부트스트랩이 늦다 (이슈 #231)
    let relaunchedForLocation = launchOptions?[.location] != nil
    AdaptiveLocationWatcher.shared.restoreOnLaunch(reason: relaunchedForLocation ? "location" : "normal")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 현재 위치 1회 조회 (이슈 #213, Android `CurrentLocationProvider` 와 같은 계약)
///
/// 스트림이 아니라 1회 조회다 — 버튼을 누른 순간만 필요하고, 계속 받으면 배터리를 먹는다.
/// 실패는 사유 코드로 돌려준다. Dart 가 그 코드를 진단 로그에 남긴다.
///
/// **`requestLocation()` 을 쓰지 않는다** (이슈 #227). 최고 정확도 1회 요청은 그 정확도에
/// 닿을 때까지 아무것도 주지 않아 실내·실기기에서 10초를 거의 매번 넘겼다. 대신
/// 최근 캐시를 먼저 보고, 없으면 갱신을 켜서 "쓸 만한" 첫 값에서 멈춘다.
final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
  /// 이 시간 안의 캐시는 지금 위치로 본다 — 지도를 내 주변으로 옮기는 용도라 충분하다
  private static let cacheMaxAge: TimeInterval = 60
  /// 캐시를 믿을 수 있는 정확도 상한 (미터)
  private static let cacheMaxAccuracy: CLLocationAccuracy = 200
  /// 갱신 중 이만큼 정확하면 더 기다리지 않고 바로 돌려준다 (미터)
  private static let goodEnoughAccuracy: CLLocationAccuracy = 100
  /// 버튼을 누르고 기다리는 시간이다 — 길면 눌렀는지 의심하게 된다
  private static let timeoutSeconds: TimeInterval = 10

  private let manager = CLLocationManager()
  private var pending: [FlutterResult] = []
  private var timeout: DispatchWorkItem?
  /// 시간 초과 시 빈손으로 끝내지 않도록 지금까지 받은 가장 정확한 값을 쥐고 있는다
  private var best: CLLocation?

  override init() {
    super.init()
    manager.delegate = self
    // 10m 급이면 GPS 를 끝까지 기다리지 않고 Wi-Fi·기지국 값으로도 빨리 닿는다
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
  }

  func fetch(_ result: @escaping FlutterResult) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      break
    default:
      result(FlutterError(code: "permission_denied", message: "status=\(manager.authorizationStatus.rawValue)", details: nil))
      return
    }

    // 연달아 눌러도 요청은 하나만 보내고 결과를 모두에게 돌려준다
    pending.append(result)
    guard pending.count == 1 else { return }

    // 최근에 다른 경로(지도·지오펜스)가 얻어 둔 값이 있으면 기다릴 이유가 없다
    if let cached = manager.location, Self.isUsableCache(cached) {
      finish(Self.payload(cached))
      return
    }

    best = nil
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      // 기준엔 못 미쳐도 받은 값이 있으면 그것이 서울시청보다 낫다
      if let best = self.best {
        self.finish(Self.payload(best))
      } else {
        self.finish(FlutterError(code: "timeout", message: "no fix within \(Int(Self.timeoutSeconds))s", details: nil))
      }
    }
    timeout = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutSeconds, execute: work)
    manager.startUpdatingLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 끝난 뒤 늦게 도착한 갱신은 버린다
    guard !pending.isEmpty else { return }
    guard !locations.isEmpty else {
      finish(FlutterError(code: "no_location", message: nil, details: nil))
      return
    }

    for location in locations where location.horizontalAccuracy >= 0 {
      if location.horizontalAccuracy < (best?.horizontalAccuracy ?? .greatestFiniteMagnitude) {
        best = location
      }
    }
    if let best, best.horizontalAccuracy <= Self.goodEnoughAccuracy {
      finish(Self.payload(best))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // locationUnknown 은 "아직 모른다"는 일시 상태다 — Apple 문서대로 무시하고 계속 기다린다
    if let clError = error as? CLError, clError.code == .locationUnknown { return }
    guard !pending.isEmpty else { return }
    finish(FlutterError(code: "location_failed", message: error.localizedDescription, details: nil))
  }

  private static func isUsableCache(_ location: CLLocation) -> Bool {
    let age = -location.timestamp.timeIntervalSinceNow
    return age <= cacheMaxAge
      && location.horizontalAccuracy >= 0
      && location.horizontalAccuracy <= cacheMaxAccuracy
  }

  private static func payload(_ location: CLLocation) -> [String: Double] {
    // accuracy 는 등록 순간 안팎 판정(이슈 #231)이 쓴다 — 지도 이동은 무시한다
    [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
    ]
  }

  private func finish(_ value: Any) {
    // 어떤 경로로 끝나든 갱신을 끈다 — 켜 둔 채 두면 배터리를 계속 먹는다
    manager.stopUpdatingLocation()
    timeout?.cancel()
    timeout = nil
    best = nil
    let waiting = pending
    pending.removeAll()
    waiting.forEach { $0(value) }
  }
}
