import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';

part 'alert_place.freezed.dart';

/// 알림을 걸어둔 장소 (docs/03-DOMAIN.md)
///
/// 용도를 전제하지 않는다 — 하차 지점, 카풀, 하원, 약속 장소, 이탈 리마인더
/// 전부 이 하나의 추상이다 (docs/01-REQUIREMENTS.md 1.3).
///
/// `id` 는 저장 전에 앱이 생성한다(UUIDv7) — 플랫폼 지오펜스 등록에
/// 식별자가 먼저 필요하다. 시각은 전부 UTC 다.
@freezed
abstract class AlertPlace with _$AlertPlace {
  const factory AlertPlace({
    required String id,
    required String name,
    required double latitude,
    required double longitude,

    /// 50 ~ 2000 (docs/01-REQUIREMENTS.md F1.4)
    required int radiusMeters,
    required AlertDirection direction,

    /// 삭제하지 않고 잠시 끄는 수단 (F1.7)
    @Default(true) bool enabled,

    /// 이어폰(줄·블루투스) 연결 시 소리를 낼지
    @Default(true) bool soundEnabled,

    /// 알림이 활성인 시간 창 (이슈 #81).
    ///
    /// **빈 목록이면 항상 활성**이다 — 창을 더하면 그 시간에만 울린다.
    /// 여러 창은 OR 이다.
    @Default(<AlertSchedule>[]) List<AlertSchedule> schedules,
    required DateTime createdAt,
  }) = _AlertPlace;
}
