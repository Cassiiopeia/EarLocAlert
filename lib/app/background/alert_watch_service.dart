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

  /// 네이티브가 지금 알림을 울리고 있는가 (이슈 #130).
  ///
  /// **앱 프로세스가 죽었다 살아나면 Dart 세션은 사라지지만 이 서비스는
  /// 살아 있다.** 그 상태를 모르면 진동이 계속되는데 띄울 화면이 없어,
  /// 사용자에게 강제 중지 말고는 방법이 없어진다.
  ///
  /// 확인에 실패하면 `false` 로 본다 — 울리지 않는데 정리를 시도하는 것은
  /// 무해하지만, 반대로 틀리면 멀쩡한 알림을 꺼버린다.
  Future<bool> isAlerting();

  /// 지오펜스 등록을 서비스에 위임한다 (이슈 #93).
  ///
  /// 등록 주체가 서비스인 이유는 **앱이 죽어도 등록이 살아있어야 하기**
  /// 때문이다. 액티비티가 소유하면 프로세스 회수와 함께 사라진다.
  ///
  /// 페이로드 키는 `AndroidGeofenceMonitor` 가 만들고 Kotlin
  /// `GeofenceRegistrar.sync` 가 읽는다 — 양쪽이 계약이다.
  Future<void> syncGeofences(List<Map<String, Object?>> geofences);
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

  @override
  Future<bool> isAlerting() async => false;

  @override
  Future<void> syncGeofences(List<Map<String, Object?>> geofences) async {}
}
