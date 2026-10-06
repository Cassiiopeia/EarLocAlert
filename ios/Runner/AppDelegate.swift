import Flutter
import UIKit
import CoreLocation
import GoogleMaps
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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 현재 위치 1회 조회 (이슈 #213, Android `CurrentLocationProvider` 와 같은 계약)
///
/// 스트림이 아니라 1회 조회다 — 버튼을 누른 순간만 필요하고, 계속 받으면 배터리를 먹는다.
/// 실패는 사유 코드로 돌려준다. Dart 가 그 코드를 진단 로그에 남긴다.
final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var pending: [FlutterResult] = []
  private var timeout: DispatchWorkItem?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
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

    // 버튼을 누르고 기다리는 시간이다 — 길면 눌렀는지 의심하게 된다
    let work = DispatchWorkItem { [weak self] in
      self?.finish(FlutterError(code: "timeout", message: "no fix within 10s", details: nil))
    }
    timeout = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    manager.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else {
      finish(FlutterError(code: "no_location", message: nil, details: nil))
      return
    }
    finish(["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(FlutterError(code: "location_failed", message: error.localizedDescription, details: nil))
  }

  private func finish(_ value: Any) {
    timeout?.cancel()
    timeout = nil
    let waiting = pending
    pending.removeAll()
    waiting.forEach { $0(value) }
  }
}
