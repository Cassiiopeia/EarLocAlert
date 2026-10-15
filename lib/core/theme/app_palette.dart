import 'package:flutter/material.dart';

import 'app_typography.dart';

/// 라이트·다크 팔레트 (이슈 #272, docs/06-UX.md)
///
/// 화면은 색 상수가 아니라 이 팔레트를 `context.palette` 로 읽는다. 상수를
/// 직접 쓰면 라이트 모드에서도 다크 색이 박혀 흰 바탕에 흰 글자가 된다.
/// 이름은 역할로 짓는다 — 색을 바꿔도 이름이 거짓말이 되지 않게.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.warning,
    required this.onWarning,
    required this.danger,
  });

  /// 화면 바탕
  final Color background;

  /// 카드·시트·목록 묶음
  final Color surface;

  /// 카드 위 요소, 선택 안 된 칸
  final Color elevated;

  /// 목록 행 사이 선
  final Color separator;

  final Color textPrimary;

  /// 보조 설명
  final Color textSecondary;

  /// 주색(민트) — 주 버튼, 선택, 도착, 감시 중
  final Color accent;
  final Color onAccent;

  /// 금색 — 출발, 감시 중지 경고
  final Color warning;
  final Color onWarning;

  /// 삭제처럼 되돌리기 어려운 동작에만 (이슈 #205)
  final Color danger;

  /// iOS 다크 그룹 배경 층위를 기준으로, 민트·금색 정체성을 남겼다
  static const dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    elevated: Color(0xFF2C2C2E),
    separator: Color(0xFF38383A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF98989F),
    accent: Color(0xFF6FE3D3),
    onAccent: Color(0xFF000000),
    warning: Color(0xFFF2B85B),
    onWarning: Color(0xFF000000),
    danger: Color(0xFFFF453A),
  );

  /// iOS 라이트 그룹 배경 기준. 민트·금색은 글자로도 쓰여 흰·회색 바탕에서
  /// 4.5:1 이 나오도록 진하게 잡았다 (#272 QA — 처음 값은 3.4:1 이었다)
  static const light = AppPalette(
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFE5E5EA),
    separator: Color(0xFFC6C6C8),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6C6C70),
    accent: Color(0xFF0A7A6D),
    onAccent: Color(0xFFFFFFFF),
    warning: Color(0xFF8F5C0E),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFE5484D),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? elevated,
    Color? separator,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? warning,
    Color? onWarning,
    Color? danger,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      separator: separator ?? this.separator,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      elevated: mix(elevated, other.elevated),
      separator: mix(separator, other.separator),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      danger: mix(danger, other.danger),
    );
  }
}

/// 팔레트 색을 입힌 글자 스타일.
///
/// [AppTypography] 는 색이 없다 — 본문색은 테마의 기본 글자색을 물려받는다.
/// 보조 설명만 회색을 입혀야 하므로 여기서 입힌다.
class AppTextStyles {
  const AppTextStyles(this._palette);

  final AppPalette _palette;

  TextStyle get alertPlaceName => AppTypography.alertPlaceName;
  TextStyle get displayLarge => AppTypography.displayLarge;
  TextStyle get screenTitle => AppTypography.screenTitle;
  TextStyle get alertTime => AppTypography.alertTime;
  TextStyle get headline => AppTypography.headline;
  TextStyle get body => AppTypography.body;
  TextStyle get caption =>
      AppTypography.caption.copyWith(color: _palette.textSecondary);
}

extension PaletteContext on BuildContext {
  /// 지금 테마의 팔레트. 테마에 없으면(테스트 등) 다크로 떨어진다
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;

  AppTextStyles get typo => AppTextStyles(palette);
}
