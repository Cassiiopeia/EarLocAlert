import Flutter
import UIKit
import GoogleMaps
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
