import 'dart:ui';

/// 앱 전체 색 토큰 (docs/06-UX.md)
///
/// 화면에서 색 값을 직접 쓰지 않는다 — 반드시 이 토큰을 거친다.
/// 값을 조정하면 docs/06-UX.md 의 표도 함께 고친다.
abstract final class AppColors {
  // 배경 — 층은 그림자가 아니라 명도 차이로 구분한다
  static const Color bgBase = Color(0xFF0D0D0D);
  static const Color bgSurface = Color(0xFF1A1A1A);
  static const Color bgElevated = Color(0xFF262626);

  // 텍스트
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // 주색 2개 — 여기서 모든 의미 색이 파생된다. 새 색을 추가하지 않는다
  static const Color primary = Color(0xFFE5B65C);
  static const Color secondary = Color(0xFF7FE8D8);

  /// 주색 위에 올라가는 텍스트 (버튼 라벨 등)
  static const Color textOnPrimary = Color(0xFF0D0D0D);
}
