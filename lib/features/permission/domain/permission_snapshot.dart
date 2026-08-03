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
  }) = _PermissionSnapshot;

  PermissionStatus statusOf(PermissionKind kind) => switch (kind) {
    PermissionKind.location => location,
    PermissionKind.backgroundLocation => backgroundLocation,
    PermissionKind.notification => notification,
  };

  /// 백그라운드 감시가 실제로 가능한 상태인가.
  ///
  /// 이 앱의 핵심 기능이 성립하는지를 나타낸다 — 화면에 감시 상태를
  /// 표시할 때 이 값을 쓴다 (docs/01-REQUIREMENTS.md F4.5).
  bool get canMonitorInBackground =>
      location.isGranted && backgroundLocation.isGranted;

  /// 알림을 띄울 수 있는가
  bool get canNotify => notification.isGranted;

  /// 앱이 온전히 동작하는가
  bool get isComplete => canMonitorInBackground && canNotify;
}
