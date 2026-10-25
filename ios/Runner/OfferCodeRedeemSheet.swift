import Flutter
import StoreKit
import UIKit

/// App Store 오퍼 코드(프로모션 코드) 입력 시트 (이슈 #305)
///
/// 비소모성 상품 오퍼 코드는 StoreKit 2 시트로만 받는다 (`AppStore.presentOfferCodeRedeemSheet`, iOS 16+).
/// iOS 16 미만은 StoreKit 1 시트로 떨어진다 — 구독 코드만 받을 수 있지만 버튼이 죽지는 않는다.
/// 코드를 쓴 거래는 결제 스트림으로 오고, 시트가 닫히면 Dart 가 보유를 다시 조회한다.
///
/// 채널 계약 (`kr.suhsaechan.ear_loc_alert/offer_code`):
/// - `present` → 시트가 닫히면 `true` / 띄우지 못하면 `false`
enum OfferCodeRedeemSheet {
  private static let channelName = "kr.suhsaechan.ear_loc_alert/offer_code"

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "present" else {
          result(FlutterMethodNotImplemented)
          return
        }
        present(result: result)
      }
  }

  private static func present(result: @escaping FlutterResult) {
    if #available(iOS 16.0, *) {
      // 지금 앞에 있는 창의 scene 위에 띄운다
      guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
      else {
        NativeDiagnosticLog.write("pro", "offer code sheet failed reason=no_active_scene")
        result(false)
        return
      }
      Task { @MainActor in
        do {
          try await AppStore.presentOfferCodeRedeemSheet(in: scene)
          NativeDiagnosticLog.write("pro", "offer code sheet closed route=storekit2")
          result(true)
        } catch {
          NativeDiagnosticLog.write("pro", "offer code sheet failed error=\(error.localizedDescription)")
          result(false)
        }
      }
    } else {
      SKPaymentQueue.default().presentCodeRedemptionSheet()
      NativeDiagnosticLog.write("pro", "offer code sheet presented route=storekit1")
      result(true)
    }
  }
}
