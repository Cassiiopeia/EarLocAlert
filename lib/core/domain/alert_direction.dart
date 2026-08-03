/// 알림 방향 (docs/01-REQUIREMENTS.md F1.5)
enum AlertDirection {
  /// 반경에 들어올 때
  enter,

  /// 반경을 벗어날 때
  exit,

  /// 둘 다
  both;

  bool get notifiesOnEnter => this == enter || this == both;

  bool get notifiesOnExit => this == exit || this == both;
}
