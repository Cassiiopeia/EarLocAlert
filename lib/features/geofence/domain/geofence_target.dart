import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';

part 'geofence_target.freezed.dart';

/// 지오펜스 판정 대상 (docs/02-ARCHITECTURE.md 규칙 1)
///
/// geofence 는 places 를 import 하지 않는다 — 판정에 필요한 값만
/// 이 타입으로 받는다. app 계층이 AlertPlace 를 여기로 매핑한다.
/// 덕분에 지오펜스 판정을 places 없이 단독 테스트할 수 있다.
@freezed
abstract class GeofenceTarget with _$GeofenceTarget {
  const factory GeofenceTarget({
    required String placeId,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required AlertDirection direction,
    @Default(true) bool enabled,

    /// 알림이 활성인 시간 창 (이슈 #81). 빈 목록이면 항상 활성이다.
    @Default(<AlertSchedule>[]) List<AlertSchedule> schedules,
  }) = _GeofenceTarget;
}
