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
  }) {
    return PlaceValidator.validate(
      name: name,
      radiusMeters: radius,
      latitude: lat,
      longitude: lng,
      currentCount: count,
      isNew: isNew,
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
}
