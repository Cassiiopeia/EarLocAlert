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
    // 비어 있으면 SDK 를 켜지 않는다 — 키 없이도 앱은 정상 동작해야 하고,
    // 빈 문자열을 넘기면 SDK 가 예외를 던져 앱이 죽는다.
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String,
       !mapsApiKey.isEmpty {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    // native_geofence — 백그라운드 isolate 에서도 플러그인(drift·알림 등)을
    // 쓸 수 있게 등록 콜백을 넘긴다 (이슈 #63)
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
