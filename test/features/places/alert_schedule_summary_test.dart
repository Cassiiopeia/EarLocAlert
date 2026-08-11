import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/features/places/presentation/alert_schedule_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스케줄 요약 문자열 (이슈 #81)
///
/// 요일 압축과 자정 넘김 표기는 틀리기 쉬워 위젯과 분리해 검증한다.
void main() {
  group('요일 압축', () {
    test('월~금 전부는 "평일"', () {
      expect(describeDaysOfWeek(const {1, 2, 3, 4, 5}), '평일');
    });

    test('토·일은 "주말"', () {
      expect(describeDaysOfWeek(const {6, 7}), '주말');
    });

    test('7일 전부는 "매일"', () {
      expect(describeDaysOfWeek(const {1, 2, 3, 4, 5, 6, 7}), '매일');
    });

    test('접히지 않는 조합은 요일 순서대로 나열한다', () {
      expect(describeDaysOfWeek(const {1, 3, 5}), '월·수·금');
    });

    test('고른 순서와 무관하게 항상 월요일부터 나열한다', () {
      expect(describeDaysOfWeek(const {5, 1, 3}), '월·수·금');
    });

    test('빈 집합은 빈 문자열', () {
      expect(describeDaysOfWeek(const {}), '');
    });
  });

  group('시각 표기', () {
    test('자정은 00:00', () {
      expect(describeMinuteOfDay(0), '00:00');
    });

    test('한 자리 시/분에 0 을 채운다', () {
      expect(describeMinuteOfDay(8 * 60 + 5), '08:05');
    });

    test('하루의 마지막 분은 23:59', () {
      expect(describeMinuteOfDay(23 * 60 + 59), '23:59');
    });
  });

  group('창 하나 요약', () {
    test('평일 오전', () {
      const schedule = AlertSchedule(
        daysOfWeek: {1, 2, 3, 4, 5},
        startMinuteOfDay: 8 * 60,
        endMinuteOfDay: 10 * 60,
      );
      expect(describeSchedule(schedule), '평일 08:00 ~ 10:00');
    });

    test('자정을 넘기면 (익일)을 붙인다', () {
      const schedule = AlertSchedule(
        daysOfWeek: {5},
        startMinuteOfDay: 23 * 60,
        endMinuteOfDay: 2 * 60,
      );
      expect(describeSchedule(schedule), '금 23:00 ~ 02:00 (익일)');
    });
  });

  group('목록 요약 (카드 한 줄)', () {
    const morning = AlertSchedule(
      daysOfWeek: {1, 2, 3, 4, 5},
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
    );
    const evening = AlertSchedule(
      daysOfWeek: {1, 2, 3, 4, 5},
      startMinuteOfDay: 18 * 60,
      endMinuteOfDay: 20 * 60,
    );

    test('빈 목록은 "항상 알림"', () {
      expect(describeSchedules(const []), '항상 알림');
    });

    test('하나면 그대로 보여준다', () {
      expect(describeSchedules(const [morning]), '평일 08:00 ~ 10:00');
    });

    test('여러 개면 첫 창 + 나머지 개수', () {
      expect(
        describeSchedules(const [morning, evening]),
        '평일 08:00 ~ 10:00 외 1개',
      );
    });
  });
}
