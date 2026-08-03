/// 간격 토큰 (docs/06-UX.md)
///
/// 이 네 개만 쓴다. 12·18·32 같은 중간값을 만들지 않는다 —
/// 간격 스케일 제한이 화면 간 통일감의 대부분을 만든다.
abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 40;
}

/// 모서리 토큰 (docs/06-UX.md)
abstract final class AppRadius {
  static const double small = 16;
  static const double card = 24;

  /// pill 버튼용
  static const double pill = 999;
}
