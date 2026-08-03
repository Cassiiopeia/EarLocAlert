import Flutter
import UIKit
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // native_geofence — 백그라운드 isolate 에서도 플러그인(drift·알림 등)을
    // 쓸 수 있게 등록 콜백을 넘긴다 (이슈 #63)
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
