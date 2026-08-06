/// 감시 상시 유지 서비스 제어 (이슈 #74)
///
/// 네이티브 포그라운드 서비스를 켜고 끈다. 이 서비스가 하는 일:
/// - 프로세스를 살려둬 절전(Doze) 중에도 지오펜스 콜백이 제때 온다
/// - 알림이 발생하면 **해제할 때까지** 반복 진동하고 앱을 전면으로 띄운다
///
/// **플랫폼 API 를 인터페이스 뒤에 둔다** (docs/02-ARCHITECTURE.md 규칙 3).
/// 감시 대상이 있을 때만 켠다 — 알릴 것이 없는데 상시 알림을 띄우면
/// 사용자에게는 그냥 배터리 먹는 앱이다.
abstract interface class AlertWatchService {
  /// 상시 감시를 시작한다. 이미 돌고 있으면 아무 일도 하지 않는다.
  Future<void> startWatching();

  /// 상시 감시를 멈춘다 — 감시 대상이 하나도 없을 때.
  Future<void> stopWatching();

  /// 네이티브가 돌리던 알림(반복 진동)을 멈춘다.
  ///
  /// **Dart 알림 세션이 시작되기 직전에 부른다.** 순서가 뒤집히면
  /// 네이티브 취소가 Dart 진동을 같이 끄거나, 둘이 겹쳐 패턴이 어긋난다.
  Future<void> stopNativeAlert();
}

/// 아무것도 하지 않는 구현 — 플랫폼 미지원(iOS)·테스트용
class NoopAlertWatchService implements AlertWatchService {
  const NoopAlertWatchService();

  @override
  Future<void> startWatching() async {}

  @override
  Future<void> stopWatching() async {}

  @override
  Future<void> stopNativeAlert() async {}
}
