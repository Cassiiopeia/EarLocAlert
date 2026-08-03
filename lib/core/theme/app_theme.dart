import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마 (docs/06-UX.md)
///
/// 다크가 기본이다 — 주 사용 환경이 버스·지하철·밤이다.
/// 그림자(elevation)를 쓰지 않는다 — 층은 배경 명도 차이로 구분한다.
abstract final class AppTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textOnPrimary,
      surface: AppColors.bgSurface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgBase,
      extensions: const [AppSemanticColors.dark],

      // 그림자 금지 — 층은 배경 명도로
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        margin: EdgeInsets.zero,
      ),

      // 주요 버튼 — 하단 전체 폭 pill (docs/06-UX.md)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          ),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        headlineMedium: AppTypography.screenTitle,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // 아이콘은 Material outlined 변형만 쓴다 (docs/06-UX.md)
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(color: AppColors.bgElevated),
    );
  }
}
