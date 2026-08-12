import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_schedule.freezed.dart';

/// 알림이 활성인 시간 구간 하나 — "창" (이슈 #81)
///
/// 장소에 창을 0개 이상 붙인다. **창이 하나도 없으면 항상 활성**이라
/// 기존에 등록된 장소의 동작이 바뀌지 않는다.
///
/// `places` 가 아니라 `core/domain` 에 있는 이유는 geofence 도 이 타입을
/// 쓰기 때문이다. `places/domain` 에 두면 geofence 가 places 를 import 하게
/// 되어 아키텍처 규칙 1 을 어긴다 ([AlertDirection] 과 같은 이유).
///
/// **시각을 UTC DateTime 이 아니라 "자정 기준 분"으로 담는다.**
/// docs/04-CONVENTIONS.md 의 UTC 규칙은 *일어난 사건의 시점*
/// (`createdAt`·`occurredAt`)에 적용된다. "평일 08:00" 은 시점이 아니라
/// 벽시계 규칙이라, UTC 로 저장하면 시간대 이동·서머타임에서 08:00 이
/// 07:00 으로 밀린다. 사용자가 원한 것은 "그곳의 아침 8시"다.
@freezed
abstract class AlertSchedule with _$AlertSchedule {
  const AlertSchedule._();

  const factory AlertSchedule({
    /// `DateTime.monday`(1) ~ `DateTime.sunday`(7)
    ///
    /// 자체 enum 을 만들지 않는 이유는 `DateTime.weekday` 와 매번 변환해야
    /// 하고 그 변환이 틀리기 쉽기 때문이다.
    required Set<int> daysOfWeek,

    /// 자정 기준 분 (0 ~ 1439)
    required int startMinuteOfDay,

    /// 자정 기준 분 (0 ~ 1439).
    /// [startMinuteOfDay] 보다 작으면 자정을 넘긴 창이다.
    required int endMinuteOfDay,
  }) = _AlertSchedule;

  /// 자정을 넘기는 창인가 (예: 23:00 ~ 02:00)
  bool get crossesMidnight => startMinuteOfDay > endMinuteOfDay;

  /// 이 창이 [localNow] 에 열려 있는가.
  ///
  /// **[localNow] 는 로컬 시각이어야 한다.** UTC 를 넘기면 사용자가 설정한
  /// 벽시계 시각과 어긋난다.
  ///
  /// 구간은 `[start, end)` — 시작은 포함, 끝은 제외다. 08:00~10:00 과
  /// 10:00~12:00 을 나란히 두었을 때 10:00 이 양쪽에 걸치지 않는다.
  bool isActiveAt(DateTime localNow) {
    final minute = localNow.hour * 60 + localNow.minute;

    if (!crossesMidnight) {
      return daysOfWeek.contains(localNow.weekday) &&
          minute >= startMinuteOfDay &&
          minute < endMinuteOfDay;
    }

    // 자정 넘김 — 요일은 **창이 시작된 날** 기준이다.
    // 금 23:00~02:00 이면 토요일 01:30 도 "금요일에 시작한 창" 안이다.
    if (minute >= startMinuteOfDay) {
      return daysOfWeek.contains(localNow.weekday); // 오늘 시작한 몫
    }
    if (minute < endMinuteOfDay) {
      final yesterday = localNow.subtract(const Duration(days: 1)).weekday;
      return daysOfWeek.contains(yesterday); // 어제 시작한 몫
    }
    return false;
  }
}

/// 창 목록 전체로 판정한다 — 하나라도 열려 있으면 활성(OR).
///
/// **빈 목록은 "항상 활성"이다.** 스케줄을 순수하게 더하는 기능으로 두기
/// 위한 규약이며, 마이그레이션된 기존 장소가 이 경로로 들어온다.
///
/// 목록을 다루는 관심사라 [AlertSchedule] 인스턴스에 매달지 않고
/// 최상위 함수로 둔다.
bool isScheduleActive(List<AlertSchedule> schedules, DateTime localNow) {
  if (schedules.isEmpty) return true;
  return schedules.any((s) => s.isActiveAt(localNow));
}
