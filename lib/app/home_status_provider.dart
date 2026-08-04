// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/alert/presentation/alert_controller_provider.dart';
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
  });

  /// 감시 대기 상태 — 확인 전에는 "꺼짐"으로 본다
  static const unknown = HomeStatus(
    isMonitoring: false,
    isHeadphoneConnected: false,
  );

  /// OS 지오펜스에 등록된 장소가 하나라도 있는가.
  ///
  /// 등록이 0건이면 권한이 없거나 활성 장소가 없다는 뜻이고,
  /// 사용자 입장에서는 둘 다 "안 울린다"로 같다.
  final bool isMonitoring;

  /// 지금 이어폰이 연결되어 있는가 (docs/10-DECISIONS.md 018)
  final bool isHeadphoneConnected;
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

  return HomeStatus(isMonitoring: monitoring, isHeadphoneConnected: headphones);
}
