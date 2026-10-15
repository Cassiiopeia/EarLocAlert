import 'package:flutter/material.dart';

import 'app_color_palette.dart';

/// 의미 색 토큰 — 두 주색에서 파생한다 (docs/06-UX.md)
///
/// `Theme.of(context).extension<AppSemanticColors>()!` 로 접근한다.
/// 진입/이탈 구분은 색만으로 하지 않는다 — 아이콘·텍스트를 병행한다 (색각 이상 대응).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.alertEnter,
    required this.alertExit,
    required this.statusActive,
    required this.statusInactive,
    required this.audioBluetooth,
  });

  /// 진입 알림 (마커·반경 원·아이콘)
  final Color alertEnter;

  /// 이탈 알림
  final Color alertExit;

  /// 감시 동작 중
  final Color statusActive;

  /// 감시 중지 — 경고로 보여야 한다
  final Color statusInactive;

  /// 이어폰 연결됨
  final Color audioBluetooth;

  /// 팔레트에서 파생한다 (이슈 #272) — 진입은 주색(민트), 이탈·중지는 금색
  factory AppSemanticColors.fromPalette(AppColorPalette p) => AppSemanticColors(
    alertEnter: p.accent,
    alertExit: p.warning,
    statusActive: p.accent,
    statusInactive: p.warning,
    audioBluetooth: p.accent,
  );

  static final AppSemanticColors dark = AppSemanticColors.fromPalette(
    AppColorPalette.dark,
  );
  static final AppSemanticColors light = AppSemanticColors.fromPalette(
    AppColorPalette.light,
  );

  @override
  AppSemanticColors copyWith({
    Color? alertEnter,
    Color? alertExit,
    Color? statusActive,
    Color? statusInactive,
    Color? audioBluetooth,
  }) {
    return AppSemanticColors(
      alertEnter: alertEnter ?? this.alertEnter,
      alertExit: alertExit ?? this.alertExit,
      statusActive: statusActive ?? this.statusActive,
      statusInactive: statusInactive ?? this.statusInactive,
      audioBluetooth: audioBluetooth ?? this.audioBluetooth,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      alertEnter: Color.lerp(alertEnter, other.alertEnter, t)!,
      alertExit: Color.lerp(alertExit, other.alertExit, t)!,
      statusActive: Color.lerp(statusActive, other.statusActive, t)!,
      statusInactive: Color.lerp(statusInactive, other.statusInactive, t)!,
      audioBluetooth: Color.lerp(audioBluetooth, other.audioBluetooth, t)!,
    );
  }
}
