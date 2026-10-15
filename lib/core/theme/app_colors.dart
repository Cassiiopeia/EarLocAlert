import 'dart:ui';

import 'app_palette.dart';

/// 다크 팔레트 값의 정적 사본 (docs/06-UX.md)
///
/// **화면에서 쓰지 않는다** (이슈 #272) — 화면은 `context.palette` 로 지금
/// 테마의 색을 읽는다. 이 상수를 쓰면 라이트 모드에서도 다크 색이 박힌다.
/// `design_system_test` 가 화면 코드의 사용을 막는다. 테마 밖에서 색이
/// 필요한 드문 자리(네이티브 경계 등)를 위해서만 남긴다.
abstract final class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color elevated = Color(0xFF2C2C2E);
  static const Color separator = Color(0xFF38383A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF98989F);
  static const Color accent = Color(0xFF6FE3D3);
  static const Color onAccent = Color(0xFF000000);
  static const Color warning = Color(0xFFF2B85B);
  static const Color onWarning = Color(0xFF000000);
  static const Color danger = Color(0xFFFF453A);

  /// 다크 팔레트와 값이 어긋나지 않았는지 테스트가 비교한다
  static const AppPalette palette = AppPalette.dark;
}
