import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림 시간대 판정 (이슈 #81)
///
/// 실기기 없이 전 경우를 확인한다 — 시각을 주입받는 순수 함수라
/// 가능하다 (docs/03-DOMAIN.md).
void main() {
  // 2026-08-10 은 월요일이다. 아래 날짜들은 전부 이 주 기준.
  //   월 8/10 · 화 8/11 · 금 8/14 · 토 8/15 · 일 8/16
  const weekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  group('일반 창 (평일 08:00~10:00)', () {
    const schedule = AlertSchedule(
      daysOfWeek: weekdays,
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
    );

    test('창 한가운데면 열려 있다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 10, 9)), isTrue);
    });

    test('시작 직전은 닫혀 있다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 10, 7, 59)), isFalse);
    });

    test('요일이 다르면 닫혀 있다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 15, 9)), isFalse); // 토
      expect(schedule.isActiveAt(DateTime(2026, 8, 16, 9)), isFalse); // 일
    });

    test('자정을 넘기지 않는 창이다', () {
      expect(schedule.crossesMidnight, isFalse);
    });
  });

  group('경계는 [start, end) — 시작 포함, 끝 제외', () {
    const schedule = AlertSchedule(
      daysOfWeek: weekdays,
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
    );

    test('시작 시각은 포함한다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 10, 8)), isTrue);
    });

    test('종료 시각은 제외한다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 10, 10)), isFalse);
    });

    test('맞붙은 두 창에 같은 시각이 양쪽으로 들지 않는다', () {
      const morning = AlertSchedule(
        daysOfWeek: weekdays,
        startMinuteOfDay: 8 * 60,
        endMinuteOfDay: 10 * 60,
      );
      const late = AlertSchedule(
        daysOfWeek: weekdays,
        startMinuteOfDay: 10 * 60,
        endMinuteOfDay: 12 * 60,
      );
      final at10 = DateTime(2026, 8, 10, 10);

      expect(morning.isActiveAt(at10), isFalse);
      expect(late.isActiveAt(at10), isTrue);
    });
  });

  group('자정 넘김 (금 23:00~02:00) — 요일은 창이 시작된 날 기준', () {
    const schedule = AlertSchedule(
      daysOfWeek: {DateTime.friday},
      startMinuteOfDay: 23 * 60,
      endMinuteOfDay: 2 * 60,
    );

    test('자정을 넘기는 창으로 인식한다', () {
      expect(schedule.crossesMidnight, isTrue);
    });

    test('금요일 밤은 열려 있다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 14, 23, 30)), isTrue);
    });

    test('토요일 새벽은 열려 있다 — 금요일에 시작한 창이다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 15, 1, 30)), isTrue);
    });

    test('토요일 밤은 닫혀 있다 — 토요일은 고르지 않았다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 15, 23, 30)), isFalse);
    });

    test('일요일 새벽은 닫혀 있다 — 토요일에 시작한 창이 없다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 16, 1, 30)), isFalse);
    });

    test('창 사이(금요일 낮)는 닫혀 있다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 14, 12)), isFalse);
    });

    test('종료 시각(02:00)은 제외한다', () {
      expect(schedule.isActiveAt(DateTime(2026, 8, 15, 2)), isFalse);
    });
  });

  group('목록 판정 (isScheduleActive)', () {
    const morning = AlertSchedule(
      daysOfWeek: weekdays,
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
    );
    const evening = AlertSchedule(
      daysOfWeek: weekdays,
      startMinuteOfDay: 18 * 60,
      endMinuteOfDay: 20 * 60,
    );

    test('빈 목록은 항상 활성 — 기존 장소의 동작이 바뀌지 않는다', () {
      expect(isScheduleActive(const [], DateTime(2026, 8, 15, 3)), isTrue);
    });

    test('여러 창은 OR — 하나라도 열려 있으면 활성', () {
      const both = [morning, evening];
      expect(isScheduleActive(both, DateTime(2026, 8, 10, 9)), isTrue);
      expect(isScheduleActive(both, DateTime(2026, 8, 10, 19)), isTrue);
    });

    test('어느 창에도 안 들면 비활성', () {
      const both = [morning, evening];
      expect(isScheduleActive(both, DateTime(2026, 8, 10, 14)), isFalse);
    });
  });
}
