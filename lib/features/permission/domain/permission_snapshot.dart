import 'package:freezed_annotation/freezed_annotation.dart';

import 'permission_kind.dart';

part 'permission_snapshot.freezed.dart';

/// 현재 권한 상태 전체 (docs/05-PLATFORM.md)
@freezed
abstract class PermissionSnapshot with _$PermissionSnapshot {
  const PermissionSnapshot._();

  const factory PermissionSnapshot({
    @Default(PermissionStatus.notRequested) PermissionStatus location,
    @Default(PermissionStatus.notRequested) PermissionStatus backgroundLocation,
    @Default(PermissionStatus.notRequested) PermissionStatus notification,
    @Default(PermissionStatus.notRequested)
    PermissionStatus batteryOptimization,
    @Default(PermissionStatus.notRequested) PermissionStatus overlay,
    @Default(PermissionStatus.notRequested) PermissionStatus fullScreenIntent,
  }) = _PermissionSnapshot;

  PermissionStatus statusOf(PermissionKind kind) => switch (kind) {
    PermissionKind.location => location,
    PermissionKind.backgroundLocation => backgroundLocation,
    PermissionKind.notification => notification,
    PermissionKind.batteryOptimization => batteryOptimization,
    PermissionKind.overlay => overlay,
    PermissionKind.fullScreenIntent => fullScreenIntent,
  };

  /// 백그라운드 감시가 실제로 가능한 상태인가.
  ///
  /// 이 앱의 핵심 기능이 성립하는지를 나타낸다 — 화면에 감시 상태를
  /// 표시할 때 이 값을 쓴다 (docs/01-REQUIREMENTS.md F4.5).
  bool get canMonitorInBackground =>
      location.isGranted && backgroundLocation.isGranted;

  /// 알림을 띄울 수 있는가
  bool get canNotify => notification.isGranted;

  /// 앱이 온전히 동작하는가.
  ///
  /// **신뢰성 권한은 여기 들어가지 않는다** — 그것들이 없어도 고중요도
  /// 알림 + 반복 진동으로 앱은 성립해야 한다 (docs/10-DECISIONS.md 006).
  bool get isComplete => canMonitorInBackground && canNotify;

  /// 화면이 켜져 있을 때 알림 화면으로 화면을 덮을 수 있는가 (이슈 #74).
  ///
  /// 없으면 사용자가 영상을 보는 중에는 헤드업 알림까지만 뜬다.
  bool get canCoverScreen => overlay.isGranted;

  /// 절전 모드에서도 지오펜스 이벤트가 제때 오는가 (이슈 #74)
  bool get survivesDoze => batteryOptimization.isGranted;

  /// 화면이 꺼졌거나 잠긴 상태에서 알림 화면을 띄울 수 있는가 (이슈 #74)
  bool get canWakeScreen => fullScreenIntent.isGranted;

  /// 백그라운드 알림이 **놓치기 어려운 형태로** 전달되는가.
  ///
  /// 온보딩에서 신뢰성 권한을 더 권할지 판단하는 기준이다. 하나라도
  /// 빠지면 어떤 상황(절전·화면 켜짐·화면 꺼짐)에서 알림이 약해진다.
  bool get canAlertReliably => survivesDoze && canCoverScreen && canWakeScreen;
}
