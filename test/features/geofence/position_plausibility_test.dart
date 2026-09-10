import 'package:ear_loc_alert/features/geofence/domain/position_plausibility.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:flutter_test/flutter_test.dart';

/// 좌표가 튀었는지 가린다 (이슈 #131)
///
/// **실기기에서 6초 만에 약 1km 를 갔다가 돌아왔다.** OS 측위가 흔들려
/// 1km 떨어진 곳에서 진입 이벤트가 왔고, 정확도는 `44m` 로 멀쩡해 보였다.
/// 정확도로는 못 막는다 — 좌표 자체가 순간이동했기 때문이다.
void main() {
  // 실기기 로그의 실제 좌표다
  final base = PositionSample(
    latitude: 37.4124647,
    longitude: 127.0999042,
    accuracyMeters: 53,
    timestamp: DateTime.utc(2026, 9, 9, 23, 0, 59),
  );

  group('speedKmhFrom', () {
    test('실기기에서 있었던 튐을 잡아낸다', () {
      final speed = speedKmhFrom(
        from: base,
        latitude: 37.4085743,
        longitude: 127.0896049,
        at: DateTime.utc(2026, 9, 9, 23, 1, 5),
        accuracyMeters: 44,
      );

      expect(speed, isNotNull);
      expect(
        speed!,
        greaterThan(maxPlausibleSpeedKmh),
        reason: '6초에 약 1km — 시속 500km 를 넘는다',
      );
    });

    test('직전 측정이 없으면 판정하지 않는다', () {
      expect(
        speedKmhFrom(
          from: null,
          latitude: 37.5,
          longitude: 127.0,
          at: DateTime.utc(2026, 9, 9, 23, 1, 5),
        ),
        isNull,
        reason: '프로세스가 막 떴을 때 첫 전이를 막으면 진짜 도착을 놓친다',
      );
    });

    test('두 측정이 거의 동시면 판정하지 않는다', () {
      expect(
        speedKmhFrom(
          from: base,
          latitude: 37.5,
          longitude: 127.2,
          at: base.timestamp.add(const Duration(milliseconds: 500)),
        ),
        isNull,
        reason: '작은 오차도 무한대에 가까운 속도가 된다',
      );
    });

    test('시계가 거꾸로 가도 죽지 않는다', () {
      expect(
        speedKmhFrom(
          from: base,
          latitude: 37.5,
          longitude: 127.2,
          at: base.timestamp.subtract(const Duration(minutes: 1)),
        ),
        isNull,
      );
    });

    test('정확도 오차 안의 차이는 이동으로 치지 않는다', () {
      // 같은 자리에서 오차만큼 흔들린 경우
      final speed = speedKmhFrom(
        from: base,
        latitude: 37.4124647,
        longitude: 127.0999042,
        at: base.timestamp.add(const Duration(seconds: 10)),
        accuracyMeters: 50,
      );

      expect(speed, 0, reason: 'GPS 오차를 속도로 계산하면 가만히 있어도 빠르게 움직인다');
    });
  });

  group('isPlausibleMove', () {
    test('걷는 속도는 통과한다', () {
      // 10초에 20m ≈ 시속 7km
      expect(
        isPlausibleMove(
          from: base,
          latitude: 37.4126447,
          longitude: 127.0999042,
          at: base.timestamp.add(const Duration(seconds: 10)),
          accuracyMeters: 5,
        ),
        isTrue,
      );
    });

    test('KTX 속도도 통과한다', () {
      // 60초에 4.5km ≈ 시속 270km
      expect(
        isPlausibleMove(
          from: base,
          latitude: 37.4529,
          longitude: 127.0999042,
          at: base.timestamp.add(const Duration(seconds: 60)),
          accuracyMeters: 10,
        ),
        isTrue,
        reason: 'KTX 를 타고 가다 도착 알림을 받는 것은 정상적인 사용이다',
      );
    });

    test('측위가 튀면 막는다', () {
      expect(
        isPlausibleMove(
          from: base,
          latitude: 37.4085743,
          longitude: 127.0896049,
          at: DateTime.utc(2026, 9, 9, 23, 1, 5),
          accuracyMeters: 44,
        ),
        isFalse,
      );
    });

    test('직전 측정이 없으면 통과시킨다', () {
      expect(
        isPlausibleMove(
          from: null,
          latitude: 37.9,
          longitude: 127.9,
          at: DateTime.utc(2026, 9, 9, 23, 1, 5),
        ),
        isTrue,
        reason: '놓치는 쪽이 가짜로 우는 쪽보다 나쁘다',
      );
    });

    test('임계는 바꿔 넣을 수 있다', () {
      // 10초에 500m ≈ 시속 180km
      final moved = isPlausibleMove(
        from: base,
        latitude: 37.4169647,
        longitude: 127.0999042,
        at: base.timestamp.add(const Duration(seconds: 10)),
        accuracyMeters: 5,
        maxSpeedKmh: 100,
      );

      expect(moved, isFalse);
    });
  });
}
