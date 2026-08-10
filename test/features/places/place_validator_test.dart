import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/features/places/domain/place_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<PlaceValidationError> validate({
    String name = '장소',
    int radius = 100,
    double lat = 37.5,
    double lng = 127.0,
    int count = 0,
    bool isNew = true,
    List<AlertSchedule> schedules = const [],
  }) {
    return PlaceValidator.validate(
      name: name,
      radiusMeters: radius,
      latitude: lat,
      longitude: lng,
      currentCount: count,
      isNew: isNew,
      schedules: schedules,
    );
  }

  group('장소 검증 (F1)', () {
    test('정상 입력은 오류가 없다', () {
      expect(validate(), isEmpty);
    });

    test('빈 이름(공백 포함)은 거부한다', () {
      expect(validate(name: '  '), contains(PlaceValidationError.emptyName));
    });

    test('반경 경계 — 50 과 2000 은 허용, 밖은 거부 (F1.4)', () {
      expect(validate(radius: 50), isEmpty);
      expect(validate(radius: 2000), isEmpty);
      expect(
        validate(radius: 49),
        contains(PlaceValidationError.radiusOutOfRange),
      );
      expect(
        validate(radius: 2001),
        contains(PlaceValidationError.radiusOutOfRange),
      );
    });

    test('좌표 범위 밖은 거부한다', () {
      expect(
        validate(lat: 91),
        contains(PlaceValidationError.invalidCoordinates),
      );
      expect(
        validate(lng: -181),
        contains(PlaceValidationError.invalidCoordinates),
      );
    });

    test('신규 등록은 20개 상한에 막힌다 (docs/05-PLATFORM.md)', () {
      expect(validate(count: 20), contains(PlaceValidationError.limitReached));
      expect(validate(count: 19), isEmpty);
    });

    test('기존 장소 수정은 상한과 무관하다', () {
      expect(validate(count: 20, isNew: false), isEmpty);
    });

    test('오류는 동시에 여러 개 보고된다', () {
      final errors = validate(name: '', radius: 10);
      expect(errors, hasLength(2));
    });
  });

  group('알림 시간대 검증 (이슈 #81)', () {
    test('창이 없는 것은 정상이다 — 항상 알림을 뜻한다', () {
      expect(validate(schedules: const []), isEmpty);
    });

    test('정상 창은 통과한다', () {
      expect(
        validate(
          schedules: const [
            AlertSchedule(
              daysOfWeek: {1, 2, 3, 4, 5},
              startMinuteOfDay: 8 * 60,
              endMinuteOfDay: 10 * 60,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('자정을 넘기는 창도 통과한다', () {
      expect(
        validate(
          schedules: const [
            AlertSchedule(
              daysOfWeek: {5},
              startMinuteOfDay: 23 * 60,
              endMinuteOfDay: 2 * 60,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('시작과 종료가 같으면 거부한다 — 0분인지 24시간인지 모호하다', () {
      expect(
        validate(
          schedules: const [
            AlertSchedule(
              daysOfWeek: {1},
              startMinuteOfDay: 9 * 60,
              endMinuteOfDay: 9 * 60,
            ),
          ],
        ),
        contains(PlaceValidationError.emptyScheduleWindow),
      );
    });

    test('요일이 비면 거부한다 — 영영 열리지 않는 창이다', () {
      expect(
        validate(
          schedules: const [
            AlertSchedule(
              daysOfWeek: {},
              startMinuteOfDay: 8 * 60,
              endMinuteOfDay: 10 * 60,
            ),
          ],
        ),
        contains(PlaceValidationError.scheduleWithoutDays),
      );
    });
  });
}
