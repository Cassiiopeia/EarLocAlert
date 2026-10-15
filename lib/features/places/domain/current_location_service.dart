/// 현재 위치를 못 얻은 이유 (이슈 #227).
///
/// 화면이 안내 문구를 고르는 데만 쓴다. 예전에는 실패가 전부 null 이라
/// 시간 초과에도 "위치 권한을 확인해주세요"가 떠서 권한 문제로 오인했다.
enum CurrentLocationFailure {
  /// 위치 권한이 없다 — 설정에서 켜야 풀린다
  permissionDenied,

  /// 권한은 있으나 측정이 안 됐다 (시간 초과 등) — 다시 누르면 될 수 있다
  measurementFailed,
}

/// 현재 위치 1회 조회의 결과. [location] 과 [failure] 중 하나만 있다.
final class CurrentLocationResult {
  const CurrentLocationResult.found(
    ({double latitude, double longitude}) this.location, {
    this.accuracyMeters,
  }) : failure = null;

  const CurrentLocationResult.failed(CurrentLocationFailure this.failure)
    : location = null,
      accuracyMeters = null;

  final ({double latitude, double longitude})? location;
  final CurrentLocationFailure? failure;

  /// 수평 정확도(미터). 네이티브가 주지 않으면 null (이슈 #231).
  ///
  /// 지도 이동에는 필요 없지만, 등록 순간 안팎을 정하는 데는 필수다 —
  /// 정확도를 모르는 좌표로 "밖"이라고 단정하면 가짜 알림이 난다.
  final double? accuracyMeters;
}

/// 현재 위치 1회 조회 (이슈 #98)
///
/// 지도의 "내 위치" 버튼이 쓴다. 예전에는 좌표를 알아낼 수단이 없어 지도
/// SDK 기본 버튼을 썼는데, 그 버튼은 **우상단 고정이라 상태 알약에 가려**
/// 잘려 보였고 사용자가 존재 자체를 몰랐다.
///
/// **플랫폼 API 를 인터페이스 뒤에 둔다** (docs/02-ARCHITECTURE.md 규칙 3).
/// Android 는 `CurrentLocationProvider.kt`, iOS 는 `AppDelegate.swift` 가 처리한다 (이슈 #213).
abstract interface class CurrentLocationService {
  /// 현재 위치. 못 얻으면 그 이유를 담는다 (이슈 #227).
  Future<CurrentLocationResult> current();
}
