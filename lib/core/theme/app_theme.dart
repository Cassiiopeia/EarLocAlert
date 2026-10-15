import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마 (docs/06-UX.md)
///
/// 라이트·다크 두 벌 (이슈 #272). 사용자가 설정에서 고르고, 기본은 기기를 따른다.
/// 알림 화면만은 항상 다크다 — 밤·대중교통에서 갑자기 흰 화면이 뜨면 눈부시다.
/// 그림자(elevation)를 쓰지 않는다 — 층은 배경 명도 차이로 구분한다.
abstract final class AppTheme {
  /// 앱 글꼴. 테마 한 곳에서만 정한다 — 스타일을 통째로 덮어쓰는 테마
  /// (스낵바 등)는 이 값을 직접 받아야 글꼴이 빠지지 않는다
  static const _fontFamily = 'Pretendard';

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.warning,
      onSecondary: p.onWarning,
      error: p.danger,
      onError: p.surface,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.elevated,
      // 선택된 칩·세그먼트 바탕과 글자. 비워 두면 흰 글자가 연한 바탕에 묻힌다
      secondaryContainer: p.accent.withValues(alpha: 0.2),
      onSecondaryContainer: p.textPrimary,
      outline: p.separator,
      outlineVariant: p.separator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // Pretendard (이슈 #145). 한글 화면비에 맞게 만들어진 글꼴이라
      // 시스템 기본보다 자간·높이가 고르게 잡힌다.
      //
      // **여기서 한 번만 지정한다** — AppTypography 의 개별 스타일에
      // fontFamily 를 적으면 한 곳을 빠뜨렸을 때 그 화면만 다른 글꼴이
      // 되고, 눈에 잘 띄지 않는다.
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: p.background,
      extensions: [p, AppSemanticColors.fromPalette(p)],

      // 그림자 금지 — 층은 배경 명도로
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        margin: EdgeInsets.zero,
      ),

      // 보조 버튼도 전체 폭 (디자인 리뷰 #155). 화면마다 감싸지 않고 여기서
      // 정해야 새로 만드는 버튼도 따라온다. 높이는 떠 있는 보조 요소와 같은 48.
      // 테두리 대신 한 층 위 바탕으로 채운다 (이슈 #272) — iOS 보조 버튼 결
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppControlSize.floating),
          backgroundColor: p.elevated,
          foregroundColor: p.textPrimary,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      // 주요 버튼 — 하단 전체 폭 캡슐 (docs/06-UX.md)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.elevated,
          disabledForegroundColor: p.textSecondary,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),

      // 글자색은 여기서 한 번에 입힌다 — 스타일 자체에는 색이 없다
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        headlineMedium: AppTypography.screenTitle,
        titleMedium: AppTypography.headline,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
      ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 상태바 아이콘도 모드를 따른다 — 라이트에서 흰 아이콘이면 안 보인다
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // 입력창 — 채운 둥근 칸, 포커스되면 주색 테두리 (이슈 #272)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.accent, width: 1.5),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.danger),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.danger, width: 1.5),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),

      // 스낵바 (이슈 #205). 화면보다 한 층 위로 띄우고, 되돌리기 같은
      // 액션은 주색으로 눈에 띄게 한다
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.elevated,
        // 스타일을 통째로 지정하면 테마의 fontFamily 가 적용되지 않는다
        contentTextStyle: AppTypography.body.copyWith(
          fontFamily: _fontFamily,
          color: p.textPrimary,
        ),
        actionTextColor: p.accent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
      // 바텀시트 모서리를 카드·홈 시트와 같은 24 로 (이슈 #228)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        dragHandleColor: p.separator,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface, elevation: 0),
      chipTheme: ChipThemeData(
        backgroundColor: p.elevated,
        selectedColor: p.accent.withValues(alpha: 0.2),
        checkmarkColor: p.textPrimary,
        labelStyle: TextStyle(color: p.textPrimary),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accent : p.elevated,
        ),
        // iOS 스위치처럼 손잡이는 모드와 무관하게 흰색이다
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      dividerTheme: DividerThemeData(color: p.separator, thickness: 0.5),
    );
  }
}
