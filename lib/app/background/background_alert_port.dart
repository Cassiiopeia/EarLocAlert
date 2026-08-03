import 'pending_alert.dart';

/// 백그라운드 판정 결과를 사용자에게 전달하는 출구 (이슈 #63)
///
/// GeofenceBackgroundProcessor 가 플랫폼 알림 API 를 직접 부르지 않게
/// 하는 경계다 — 덕분에 판정·저장·알림 여부 로직을 실기기 없이
/// 테스트할 수 있다.
abstract interface class BackgroundAlertPort {
  /// 사용자에게 알림을 전달한다.
  ///
  /// 백그라운드에서 할 수 있는 것은 OS 알림 발행과 PendingAlert 저장뿐이다
  /// (docs/02-ARCHITECTURE.md 규칙 5). 반복 진동·오디오는 앱이 열린 뒤
  /// PendingAlertLauncher 가 시작한다.
  Future<void> notify(PendingAlert alert);
}
