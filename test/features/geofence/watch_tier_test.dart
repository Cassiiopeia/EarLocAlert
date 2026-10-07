import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:ear_loc_alert/features/geofence/domain/position_sample.dart';
import 'package:ear_loc_alert/features/geofence/domain/watch_tier.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS 적응형 감시 단계 선택 (이슈 #231)
///
/// 단계는 Dart 한 곳에서만 고른다 — 네이티브는 적용만 한다. 이 테스트가
/// 그 규칙(거리·정확도·히스테리시스·정밀 상한)을 지킨다.
void main() {
  final t0 = DateTime.utc(2026, 10, 8, 12);

  group('nearestRingGapMeters', () {
    // 반경 300m → 근접 원 900m (max(300×3, 500))
    const target = GeofenceTarget(
      placeId: 'a',
      latitude: 37.5,
      longitude: 127.0,
      radiusMeters: 300,
      direction: AlertDirection.enter,
    );

    PositionSample fixAt(double latitude) => PositionSample(
      latitude: latitude,
      longitude: 127.0,
      accuracyMeters: 10,
      timestamp: t0,
    );

    test('근접 원 밖이면 양수, 안이면 음수다', () {
      // 위도 0.01° ≈ 1112m
      final outside = nearestRingGapMeters(fixAt(37.51), [target])!;
      expect(outside, closeTo(1112 - 900, 5));

      final inside = nearestRingGapMeters(fixAt(37.5), [target])!;
      expect(inside, closeTo(-900, 1));
    });

    test('가장 가까운 장소 기준이고, 꺼진 장소는 보지 않는다', () {
      final far = target.copyWith(placeId: 'far', latitude: 38.0);
      final disabledNear = target.copyWith(placeId: 'off', enabled: false);

      final gap = nearestRingGapMeters(fixAt(37.9), [far, disabledNear])!;

      // 꺼진 장소(37.5)가 더 가깝지만 무시하고 38.0 기준으로 잰다
      expect(gap, closeTo(11120 - 900, 20));
    });

    test('활성 장소가 없으면 null', () {
      expect(nearestRingGapMeters(fixAt(37.5), const []), isNull);
    });
  });

  group('WatchTierPolicy', () {
    test('거리에 따라 먼·중간·정밀을 고른다', () {
      final policy = WatchTierPolicy(initial: WatchTier.far);

      expect(
        policy.next(gapMeters: 10000, accuracyMeters: 10, at: t0),
        WatchTier.far,
      );
      expect(
        policy.next(gapMeters: 2000, accuracyMeters: 10, at: t0),
        WatchTier.mid,
      );
      expect(
        policy.next(gapMeters: -5, accuracyMeters: 10, at: t0),
        WatchTier.precise,
      );
    });

    test('정확도만큼 가깝게 본다 — km 급 측정은 일찍 올린다', () {
      final policy = WatchTierPolicy(initial: WatchTier.far);

      // 남은 거리 3500m 지만 정확도 1000m — 2500m 로 보고 중간으로 올린다
      expect(
        policy.next(gapMeters: 3500, accuracyMeters: 1000, at: t0),
        WatchTier.mid,
      );
      // 근접 원까지 80m 남았어도 정확도 100m 면 안으로 본다
      expect(
        policy.next(gapMeters: 80, accuracyMeters: 100, at: t0),
        WatchTier.precise,
      );
    });

    test('내릴 때는 여유를 둔다 — 경계에서 단계가 오락가락하지 않는다', () {
      final policy = WatchTierPolicy(initial: WatchTier.far);
      policy.next(gapMeters: 2900, accuracyMeters: 0, at: t0);
      expect(policy.tier, WatchTier.mid);

      // 3000m 를 살짝 넘어도 3300m 전까지는 중간 유지
      expect(
        policy.next(gapMeters: 3200, accuracyMeters: 0, at: t0),
        WatchTier.mid,
      );
      expect(
        policy.next(gapMeters: 3400, accuracyMeters: 0, at: t0),
        WatchTier.far,
      );
    });

    test('정밀은 근접 원을 150m 넘게 벗어나야 내린다', () {
      final policy = WatchTierPolicy();
      policy.next(gapMeters: -10, accuracyMeters: 5, at: t0);
      expect(policy.tier, WatchTier.precise);

      expect(
        policy.next(gapMeters: 100, accuracyMeters: 0, at: t0),
        WatchTier.precise,
      );
      expect(
        policy.next(gapMeters: 200, accuracyMeters: 0, at: t0),
        WatchTier.mid,
      );
    });

    test('정밀은 30분 상한 — 넘으면 중간으로 쉬고, 근접 원을 벗어나야 다시 정밀', () {
      final policy = WatchTierPolicy();
      policy.next(gapMeters: -100, accuracyMeters: 5, at: t0);
      expect(
        policy.next(
          gapMeters: -100,
          accuracyMeters: 5,
          at: t0.add(const Duration(minutes: 29)),
        ),
        WatchTier.precise,
      );

      final capped = policy.next(
        gapMeters: -100,
        accuracyMeters: 5,
        at: t0.add(const Duration(minutes: 30)),
      );
      expect(capped, WatchTier.mid);
      expect(policy.preciseCapped, isTrue);

      // 근접 원 안에 머무는 동안은 계속 쉰다 — 집 근처 장소에 GPS 를 켜 두지 않는다
      expect(
        policy.next(
          gapMeters: -50,
          accuracyMeters: 50,
          at: t0.add(const Duration(minutes: 40)),
        ),
        WatchTier.mid,
      );

      // 벗어났다 다시 들어오면 다시 정밀
      policy.next(
        gapMeters: 500,
        accuracyMeters: 50,
        at: t0.add(const Duration(minutes: 50)),
      );
      expect(policy.preciseCapped, isFalse);
      expect(
        policy.next(
          gapMeters: -10,
          accuracyMeters: 5,
          at: t0.add(const Duration(minutes: 55)),
        ),
        WatchTier.precise,
      );
    });

    test('감시할 장소가 없으면 먼 단계', () {
      final policy = WatchTierPolicy(initial: WatchTier.precise);
      expect(
        policy.next(gapMeters: null, accuracyMeters: 5, at: t0),
        WatchTier.far,
      );
    });
  });
}
