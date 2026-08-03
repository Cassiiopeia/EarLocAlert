import 'package:ear_loc_alert/features/ads/domain/ad_frequency_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이 로직이 깨지면 AdMob 정책 위반 → 계정 정지다 (docs/07-MONETIZATION.md).
void main() {
  const policy = AdFrequencyPolicy(); // 간격 3분, 일 상한 10
  final now = DateTime.utc(2026, 8, 3, 12);

  group('전면광고 빈도 제어 (F8.3, F8.4)', () {
    test('조건을 모두 만족하면 노출 가능', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: now.subtract(const Duration(minutes: 10)),
          shownToday: 3,
          isFirstLaunch: false,
        ),
        isTrue,
      );
    });

    test('직전 노출 후 3분이 지나지 않았으면 거부 — 연속 알림 중복 차단', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: now.subtract(const Duration(minutes: 2, seconds: 59)),
          shownToday: 0,
          isFirstLaunch: false,
        ),
        isFalse,
      );
    });

    test('정확히 3분 경과부터 허용', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: now.subtract(const Duration(minutes: 3)),
          shownToday: 0,
          isFirstLaunch: false,
        ),
        isTrue,
      );
    });

    test('일일 상한 도달 시 거부', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: now.subtract(const Duration(hours: 1)),
          shownToday: 10,
          isFirstLaunch: false,
        ),
        isFalse,
      );
    });

    test('첫 노출(이전 기록 없음)은 간격 검사 없이 허용', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: null,
          shownToday: 0,
          isFirstLaunch: false,
        ),
        isTrue,
      );
    });

    test('앱 최초 실행에서는 노출하지 않는다 — 첫인상을 광고로 만들지 않는다', () {
      expect(
        policy.canShowInterstitial(
          now: now,
          lastShownAt: null,
          shownToday: 0,
          isFirstLaunch: true,
        ),
        isFalse,
      );
    });
  });
}
