/// 이 앱이 필요로 하는 권한 (docs/05-PLATFORM.md)
enum PermissionKind {
  /// 앱 사용 중 위치 — 지도에 현재 위치를 띄운다
  location,

  /// 항상 위치 — **없으면 앱의 존재 이유가 사라진다**
  ///
  /// Android API 30+ 는 앱 내 다이얼로그로 받을 수 없고 시스템 설정으로
  /// 보내야 한다. iOS 는 사용 중 허용을 먼저 받은 뒤 OS 가 적절한 시점에
  /// 상향을 묻는다.
  backgroundLocation,

  /// 알림 — Android 13+ 런타임 요청
  notification,

  /// 배터리 최적화 예외 — **없으면 절전 중 지오펜스 이벤트가 지연·누락된다**
  ///
  /// Doze 와 제조사 절전(삼성 등)은 앱 프로세스를 재우고 콜백을 묶어서
  /// 늦게 전달한다. "버스에서 내릴 곳"처럼 타이밍이 전부인 알림에서는
  /// 몇 분 지연이 곧 실패다 (이슈 #74).
  batteryOptimization,

  /// 다른 앱 위에 표시 — **화면이 켜져 있을 때 알림 화면을 덮는 유일한 수단**
  ///
  /// 전체화면 알림(FSI)은 잠금화면에서만 액티비티를 띄운다. 사용자가
  /// 영상을 보는 중이면 OS 가 헤드업 알림으로 강등하므로, 화면을 실제로
  /// 덮으려면 이 권한이 필요하다. 백그라운드 액티비티 시작 제한의
  /// 면제 조건이기도 하다 (이슈 #74).
  overlay,

  /// 전체화면 알림 — 화면이 꺼졌거나 잠긴 상태를 담당한다
  ///
  /// Android 14+ 는 매니페스트 선언만으로 부여되지 않는다. 알람·통화
  /// 계열이 아닌 앱은 설정 화면에서 사용자가 직접 켜야 한다
  /// (docs/10-DECISIONS.md 006 재검토).
  fullScreenIntent;

  /// 이것이 없으면 앱의 존재 이유가 사라지는 권한인가.
  ///
  /// 나머지(신뢰성 권한)는 **얹는 것이지 전제가 아니다** — 거부돼도
  /// 고중요도 알림 + 반복 진동으로 앱이 성립해야 한다.
  bool get isEssential => switch (this) {
    PermissionKind.location ||
    PermissionKind.backgroundLocation ||
    PermissionKind.notification => true,
    PermissionKind.batteryOptimization ||
    PermissionKind.overlay ||
    PermissionKind.fullScreenIntent => false,
  };
}

/// 권한 상태 (docs/04-CONVENTIONS.md)
///
/// 권한 거부는 예외가 아니라 **정상적으로 발생하는 상태**다.
/// 예외로 던지지 않고 상태로 표현한다.
enum PermissionStatus {
  /// 아직 요청한 적 없음
  notRequested,

  granted,

  /// 거부됨 — **다시 요청할 수 있다**
  denied,

  /// 영구 거부 — 앱 설정 화면으로 보내야 한다
  permanentlyDenied,

  /// 기기 정책 등으로 제한됨 — 사용자가 바꿀 수 없다
  restricted;

  bool get isGranted => this == granted;

  /// 앱 내 다이얼로그로 다시 요청할 수 있는가.
  ///
  /// [permanentlyDenied] 와 [denied] 를 구분하지 않으면 사용자가 영원히
  /// 막힌다 — 전자는 설정으로 보내야 하고 후자는 재요청이 통한다.
  bool get canRequestAgain => this == notRequested || this == denied;

  /// 설정 화면으로 보내야 하는가
  bool get needsSettings => this == permanentlyDenied;
}
