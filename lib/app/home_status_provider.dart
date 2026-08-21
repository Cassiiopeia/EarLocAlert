// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/permission/presentation/permission_controller.dart';
import 'geofence_providers.dart';

part 'home_status_provider.g.dart';

/// 메인 화면 상태 바에 필요한 값 (docs/06-UX.md F4.5)
///
/// `geofence` 와 `alert` 두 feature 에서 왔다. 화면은 어느 feature 것도
/// 직접 import 하지 않고 이 값만 받는다 (docs/02-ARCHITECTURE.md 규칙 1).
class HomeStatus {
  const HomeStatus({
    required this.isMonitoring,
    required this.isHeadphoneConnected,
    required this.canAlertReliably,
    this.missingReliability = const [],
  });

  /// 감시 대기 상태 — 확인 전에는 "꺼짐"으로 본다.
  ///
  /// 다만 [canAlertReliably] 는 확인 전에 **true** 다 — 모르는 상태에서
  /// 경고부터 띄우면 정상인 사용자에게 없는 문제를 보여주게 된다.
  static const unknown = HomeStatus(
    isMonitoring: false,
    isHeadphoneConnected: false,
    canAlertReliably: true,
    missingReliability: [],
  );

  /// OS 지오펜스에 등록된 장소가 하나라도 있는가.
  ///
  /// 등록이 0건이면 권한이 없거나 활성 장소가 없다는 뜻이고,
  /// 사용자 입장에서는 둘 다 "안 울린다"로 같다.
  final bool isMonitoring;

  /// 지금 이어폰이 연결되어 있는가 (docs/10-DECISIONS.md 018)
  final bool isHeadphoneConnected;

  /// 아직 켜지지 않은 신뢰성 권한 이름 (이슈 #115).
  ///
  /// **무엇이 빠졌는지 말해주지 않으면 배너가 쓸모없다** — "알림이
  /// 약합니다"만 보고는 무엇을 해야 할지 알 수 없다.
  final List<String> missingReliability;

  /// 백그라운드 알림이 놓치기 어려운 형태로 전달되는가 (이슈 #74).
  ///
  /// false 면 알림이 오긴 하지만 절전 중 지연되거나, 다른 앱을 보는 중에는
  /// 화면을 덮지 못한다. 감시 자체는 정상이라 **고장이 아니라 약함**으로
  /// 표시하고, 켜러 가는 경로를 준다.
  final bool canAlertReliably;
}

/// **실패를 예외로 올리지 않는다.** 상태 표시가 안 된다고 홈 화면이
/// 깨지면 안 된다 — 모르면 보수적으로 "꺼짐"을 보여준다.
@riverpod
Future<HomeStatus> homeStatus(Ref ref) async {
  var monitoring = false;
  try {
    final registered = await ref
        .watch(geofenceMonitorProvider)
        .registeredPlaceIds();
    monitoring = registered.isNotEmpty;
  } on Object {
    monitoring = false;
  }

  var headphones = false;
  try {
    headphones = await ref
        .watch(alertSoundServiceProvider)
        .isHeadphoneConnected();
  } on Object {
    headphones = false;
  }

  // 권한 조회가 아직 안 끝났으면 경고하지 않는다 — 모르는 상태에서
  // 경고를 띄우면 정상인 사용자에게 없는 문제를 보여준다 (이슈 #74)
  final snapshot = ref.watch(permissionControllerProvider).valueOrNull;
  final reliable = snapshot?.canAlertReliably ?? true;

  // 켜지지 않은 것만 골라 이름을 붙인다 — 설정 화면의 항목명과 같은
  // 말을 써야 사용자가 그 자리를 찾는다
  final missing = <String>[
    if (snapshot != null) ...[
      if (!snapshot.survivesDoze) '배터리 최적화 제외',
      if (!snapshot.canCoverScreen) '다른 앱 위에 표시',
      if (!snapshot.canWakeScreen) '전체 화면 알림',
    ],
  ];

  // 홈 상태 배너가 왜 떴는지/안 떴는지는 이 값 없이 추적할 수 없다
  final permission = ref.watch(permissionControllerProvider);
  Diagnostics.log(
    'home',
    '상태 감시=$monitoring 이어폰=$headphones 알림신뢰=$reliable '
        '미허용=[${missing.join(",")}] '
        '(권한조회=${permission.isLoading ? "진행중" : "완료"})',
  );

  return HomeStatus(
    isMonitoring: monitoring,
    isHeadphoneConnected: headphones,
    canAlertReliably: reliable,
    missingReliability: missing,
  );
}
