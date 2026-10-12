import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/features/geofence/domain/schedule_windows_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 시간대 → 네이티브 문자열 (이슈 #260)
///
/// Kotlin `WatchPlace.parseWindows` 가 같은 형식을 읽는다. 이 테스트가
/// 형식을 고정하지 않으면 한쪽만 바뀌어 시간대 가드가 조용히 꺼진다.
void main() {
  test('창이 없으면 빈 문자열이다', () {
    expect(encodeScheduleWindows(const []), '');
  });

  test('평일 07:45~10:00 은 12345,465,600 이다', () {
    final encoded = encodeScheduleWindows(const [
      AlertSchedule(
        daysOfWeek: {1, 2, 3, 4, 5},
        startMinuteOfDay: 7 * 60 + 45,
        endMinuteOfDay: 10 * 60,
      ),
    ]);
    expect(encoded, '12345,465,600');
  });

  test('여러 창은 세미콜론으로 잇고 요일은 정렬한다', () {
    final encoded = encodeScheduleWindows(const [
      AlertSchedule(
        daysOfWeek: {7, 6},
        startMinuteOfDay: 600,
        endMinuteOfDay: 720,
      ),
      AlertSchedule(
        daysOfWeek: {3, 1},
        startMinuteOfDay: 1380,
        endMinuteOfDay: 120, // 자정을 넘기는 창
      ),
    ]);
    expect(encoded, '67,600,720;13,1380,120');
  });
}
