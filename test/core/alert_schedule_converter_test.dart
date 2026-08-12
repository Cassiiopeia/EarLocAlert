import 'package:ear_loc_alert/core/database/alert_schedule_converter.dart';
import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스케줄 ↔ JSON 왕복 (이슈 #81)
///
/// 별도 테이블 대신 JSON 컬럼을 쓰기로 했으므로, 관계형 스키마가 대신
/// 지켜주던 것(필드 누락·타입 오류)을 여기서 지켜야 한다.
void main() {
  const converter = AlertScheduleListConverter();

  const morning = AlertSchedule(
    daysOfWeek: {1, 2, 3, 4, 5},
    startMinuteOfDay: 8 * 60,
    endMinuteOfDay: 10 * 60,
  );
  const overnight = AlertSchedule(
    daysOfWeek: {5},
    startMinuteOfDay: 23 * 60,
    endMinuteOfDay: 2 * 60,
  );

  group('왕복', () {
    test('빈 목록', () {
      expect(converter.fromSql(converter.toSql(const [])), isEmpty);
    });

    test('창 하나', () {
      final restored = converter.fromSql(converter.toSql(const [morning]));
      expect(restored, [morning]);
    });

    test('여러 창의 순서가 유지된다', () {
      final restored = converter.fromSql(
        converter.toSql(const [morning, overnight]),
      );
      expect(restored, [morning, overnight]);
    });

    test('자정 넘김 창도 그대로 돌아온다', () {
      final restored = converter.fromSql(converter.toSql(const [overnight]));
      expect(restored.single.crossesMidnight, isTrue);
    });
  });

  test('요일은 정렬해서 저장한다 — 같은 값이 항상 같은 문자열이 된다', () {
    const a = AlertSchedule(
      daysOfWeek: {5, 1, 3},
      startMinuteOfDay: 60,
      endMinuteOfDay: 120,
    );
    const b = AlertSchedule(
      daysOfWeek: {1, 3, 5},
      startMinuteOfDay: 60,
      endMinuteOfDay: 120,
    );
    expect(converter.toSql(const [a]), converter.toSql(const [b]));
  });

  group('깨진 데이터를 만나도 앱이 죽지 않는다', () {
    // 스케줄을 잃으면 "항상 알림"으로 떨어진다 — 조용히 안 울리는 것보다
    // 안전한 방향이다.
    test('빈 문자열', () {
      expect(converter.fromSql(''), isEmpty);
    });

    test('JSON 이 아닌 문자열', () {
      expect(converter.fromSql('not json'), isEmpty);
    });

    test('배열이 아닌 JSON', () {
      expect(converter.fromSql('{"days":[1]}'), isEmpty);
    });

    test('필드가 빠진 항목은 건너뛴다', () {
      final restored = converter.fromSql('[{"days":[1]}]');
      expect(restored, isEmpty);
    });

    test('타입이 틀린 항목은 건너뛴다', () {
      final restored = converter.fromSql(
        '[{"days":[1],"start":"08:00","end":600}]',
      );
      expect(restored, isEmpty);
    });

    test('성한 항목만 살린다', () {
      final restored = converter.fromSql(
        '[{"days":[1]},{"days":[1,2,3,4,5],"start":480,"end":600}]',
      );
      expect(restored, [morning]);
    });
  });
}
