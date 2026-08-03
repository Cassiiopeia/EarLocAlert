import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 타이포 토큰 (docs/06-UX.md)
///
/// 위계는 크기보다 굵기와 명도로 만든다 — 큰 흰 글자 옆의 작은 회색 글자.
/// Pretendard 폰트 에셋은 UI 구현 단계에서 함께 추가한다.
abstract final class AppTypography {
  /// 알림 화면 장소명 — 앱에서 가장 큰 글자
  static const TextStyle alertPlaceName = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// 화면 대표 수치
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// 화면 제목
  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// 본문
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// 보조 설명 — textSecondary 와 함께 쓴다
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );
}
