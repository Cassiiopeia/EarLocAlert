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
    this.isKnown = true,
  });

  /// 아직 확인하지 못한 상태.
  ///
  /// **"꺼짐"으로 그리지 않는다** (이슈 #142 QA). 예전에는 확인 전 값이
  /// 감시=false 라, 알림을 끄고 홈으로 돌아올 때마다 0.5~3초 동안
  /// "감시 꺼짐 ›" 이 떴다 — 멀쩡한 사용자에게 고장을 보여주고, 누르면
  /// 권한 화면으로 보냈다. [canAlertReliably] 를 확인 전에 true 로 두는
  /// 것과 같은 이유다 — 모르는 상태에서 경고부터 띄우지 않는다.
  static const unknown = HomeStatus(
    isMonitoring: false,
    isHeadphoneConnected: false,
    canAlertReliably: true,
    missingReliability: [],
    isKnown: false,
  );

  /// 값을 실제로 확인했는가. false 면 화면은 "확인 중"으로 보여준다
  final bool isKnown;

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
/// 깨지면 안 된다 — 조회가 실패하면 "꺼짐"을 보여준다. 조회가 **끝나기
/// 전**과는 다르다 — 그때는 [HomeStatus.unknown] 이다.
/// 마지막으로 남긴 홈 상태 줄 (이슈 #146)
///
/// provider 는 다시 만들어질 수 있으므로 파일 수준에 둔다. 값이 아니라
/// **기록 여부**를 가리는 용도라 상태로 취급하지 않는다.
String? _lastLoggedStatus;

@riverpod
Future<HomeStatus> homeStatus(Ref ref) async {
  // **등록 동기화가 끝나면 다시 읽는다** (이슈 #142 QA). 첫 장소를
  // 등록해도 다시 읽지 않아, 감시가 도는데 "감시 꺼짐 ›" 이 떠 있었다.
  // 동기화는 장소 목록이 바뀔 때마다 돈다 — 등록·수정·삭제·토글 전부
  final synced = ref
      .watch(geofenceSyncSignalProvider)
      .stream
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(synced.cancel);

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

  // 홈 상태 배너가 왜 떴는지/안 떴는지는 이 값 없이 추적할 수 없다.
  //
  // **바뀐 경우에만 남긴다** (이슈 #146). 이 provider 는 지켜보는 값이
  // 하나라도 흔들리면 다시 계산되는데, 예전에는 결과가 이전과 완전히
  // 같아도 매번 기록했다. 하루에 6972줄이 쌓인 날이 있었고, 로그 파일은
  // 상한에서 오래된 것부터 지워지므로 **정작 필요한 판정 기록이 그만큼
  // 빨리 밀려났다.** 같은 값이 7000번 찍힌 것에는 정보가 없다.
  final permission = ref.watch(permissionControllerProvider);
  final line =
      '상태 감시=$monitoring 이어폰=$headphones 알림신뢰=$reliable '
      '미허용=[${missing.join(",")}] '
      '(권한조회=${permission.isLoading ? "진행중" : "완료"})';
  if (line != _lastLoggedStatus) {
    _lastLoggedStatus = line;
    Diagnostics.log('home', line);
  }

  return HomeStatus(
    isMonitoring: monitoring,
    isHeadphoneConnected: headphones,
    canAlertReliably: reliable,
    missingReliability: missing,
  );
}
