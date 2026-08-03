import 'package:ear_loc_alert/core/domain/retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);

  group('이력 보관 기간 (docs/03-DOMAIN.md)', () {
    test('컷오프는 90일 전이다', () {
      expect(RetentionPolicy.cutoffFrom(now), DateTime.utc(2026, 5, 5, 12));
    });

    test('로컬 시각을 넣어도 UTC 기준으로 계산한다', () {
      final local = DateTime.utc(2026, 8, 3, 12).toLocal();
      expect(
        RetentionPolicy.cutoffFrom(local),
        RetentionPolicy.cutoffFrom(now),
      );
    });

    test('89일 된 기록은 보존 대상이다', () {
      final event = now.subtract(const Duration(days: 89));
      expect(event.isAfter(RetentionPolicy.cutoffFrom(now)), isTrue);
    });

    test('91일 된 기록은 삭제 대상이다', () {
      final event = now.subtract(const Duration(days: 91));
      expect(event.isBefore(RetentionPolicy.cutoffFrom(now)), isTrue);
    });
  });
}
