import 'package:freezed_annotation/freezed_annotation.dart';

part 'geofence_event.freezed.dart';

/// 진입/이탈 이벤트 종류
enum GeofenceEventType { entered, exited }

/// 진입/이탈 이력 (docs/03-DOMAIN.md)
///
/// F7(이력 조회)은 Phase 2 지만 이 기록은 MVP 부터 남긴다.
/// "안 울렸다"는 문제가 왔을 때 판정이 안 된 것인지, 판정은 됐는데
/// 알림이 실패한 것인지 구분할 유일한 수단이다 — 그 구분이 [notified] 다.
@freezed
abstract class GeofenceEvent with _$GeofenceEvent {
  const factory GeofenceEvent({
    required String id,

    /// 값 참조 — AlertPlace 객체를 들고 있지 않는다
    required String placeId,
    required GeofenceEventType type,

    /// UTC
    required DateTime occurredAt,

    /// 판정 시점의 실제 위치
    required double latitude,
    required double longitude,

    /// 판정 시점의 GPS 정확도 — 오작동 조사의 핵심 단서
    required double accuracyMeters,

    /// 실제로 알림을 띄웠는지
    required bool notified,
  }) = _GeofenceEvent;
}
