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
  /// 앱 글꼴. 테마 한 곳에서만 정한다 — 스타일을 통째로 덮어쓰는 테마
  /// (스낵바 등)는 이 값을 직접 받아야 글꼴이 빠지지 않는다
  static const _fontFamily = 'Pretendard';

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

      // Pretendard (이슈 #145). 한글 화면비에 맞게 만들어진 글꼴이라
      // 시스템 기본보다 자간·높이가 고르게 잡힌다. 다른 프로젝트와도
      // 같은 글꼴을 쓴다.
      //
      // **여기서 한 번만 지정한다** — AppTypography 의 개별 스타일에
      // fontFamily 를 적으면 한 곳을 빠뜨렸을 때 그 화면만 다른 글꼴이
      // 되고, 눈에 잘 띄지 않는다.
      fontFamily: _fontFamily,
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
      // 보조 버튼도 전체 폭 (디자인 리뷰 #155). 예전엔 "지도에서 다시
      // 선택"·"음원 추가" 는 전체 폭, "시간대 추가"·"미리듣기" 는 글자만큼이라
      // 같은 역할이 두 모양이었다. 화면마다 감싸지 않고 여기서 정해야 새로
      // 만드는 버튼도 따라온다. 높이는 떠 있는 보조 요소와 같은 48
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppControlSize.floating),
        ),
      ),
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
      // 스낵바 (이슈 #205). 지정하지 않으면 다크 스킴이 밝은 막대로 칠해
      // 어두운 화면에서 혼자 튄다 — 한 층 위(bgElevated)로 맞춘다.
      // 되돌리기 같은 액션은 주색으로 눈에 띄게 한다
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgElevated,
        // 스타일을 통째로 지정하면 테마의 fontFamily 가 적용되지 않는다
        contentTextStyle: AppTypography.body.copyWith(
          fontFamily: _fontFamily,
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.primary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
      // 바텀시트 모서리를 카드·홈 시트와 같은 24 로 (이슈 #228). 지정하지
      // 않으면 머티리얼 기본 28 이라 시간대·알림음 시트만 더 둥글었다
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(color: AppColors.bgElevated),
    );
  }
}
