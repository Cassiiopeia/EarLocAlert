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
