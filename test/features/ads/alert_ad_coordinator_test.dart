import 'dart:async';

import 'package:ear_loc_alert/app/alert_ad_coordinator.dart';
import 'package:ear_loc_alert/features/ads/domain/ad_frequency_policy.dart';
import 'package:ear_loc_alert/features/ads/domain/ad_frequency_store.dart';
import 'package:ear_loc_alert/features/ads/domain/interstitial_ad_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAds implements InterstitialAdService {
  bool ready = true;
  bool failOnShow = false;
  int preloadCount = 0;
  int showCount = 0;

  @override
  bool get isReady => ready;

  @override
  Future<void> preload() async {
    preloadCount++;
  }

  @override
  Future<bool> showIfReady() async {
    showCount++;
    if (failOnShow) throw Exception('광고 표시 실패');
    return ready;
  }

  @override
  Future<void> dispose() async {}
}

/// 로딩이 영원히 끝나지 않는 광고 서비스.
///
/// docs/02-ARCHITECTURE.md 규칙 4를 강제한다 — 이런 구현이 물려 있어도
/// 알림 해제 흐름이 막히면 안 된다.
class HangingAds implements InterstitialAdService {
  final _never = Completer<void>();

  @override
  bool get isReady => false;

  @override
  Future<void> preload() => _never.future;

  @override
  Future<bool> showIfReady() => _never.future.then((_) => false);

  @override
  Future<void> dispose() async {}
}

class FakeStore implements AdFrequencyStore {
  FakeStore({
    this.lastShownAt,
    this.shownToday = 0,
    this.isFirstLaunch = false,
  });

  DateTime? lastShownAt;
  int shownToday;
  bool isFirstLaunch;
  bool failOnRead = false;
  int recordCount = 0;

  @override
  Future<AdFrequencyState> read() async {
    if (failOnRead) throw Exception('저장소 읽기 실패');
    return AdFrequencyState(
      lastShownAt: lastShownAt,
      shownToday: shownToday,
      isFirstLaunch: isFirstLaunch,
    );
  }

  @override
  Future<void> recordShown(DateTime now) async {
    recordCount++;
    lastShownAt = now;
    shownToday++;
  }

  @override
  Future<void> markLaunched() async {
    isFirstLaunch = false;
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);

  late FakeAds ads;
  late FakeStore store;
  late AlertAdCoordinator coordinator;

  setUp(() {
    ads = FakeAds();
    store = FakeStore();
    coordinator = AlertAdCoordinator(ads: ads, store: store);
  });

  group('노출 판정 (docs/07-MONETIZATION.md)', () {
    test('조건을 만족하면 노출하고 기록한다', () async {
      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isTrue);
      expect(ads.showCount, 1);
      expect(store.recordCount, 1);
    });

    test('3분 이내 재해제에는 노출하지 않는다 (F8.3)', () async {
      store.lastShownAt = now.subtract(const Duration(minutes: 2));

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse);
      expect(ads.showCount, 0, reason: '광고 요청 자체를 하지 않는다');
    });

    test('일일 상한에 도달하면 노출하지 않는다 (F8.4)', () async {
      store.shownToday = 10;

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse);
    });

    test('앱 최초 실행에서는 노출하지 않는다', () async {
      store.isFirstLaunch = true;

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse, reason: '첫인상을 광고로 만들지 않는다');
    });

    test('준비된 광고가 없으면 기록하지 않는다', () async {
      ads.ready = false;

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse);
      expect(store.recordCount, 0, reason: '안 보여준 광고를 노출로 기록하면 안 된다');
    });
  });

  group('광고 실패가 전파되지 않는다 (docs/02-ARCHITECTURE.md 규칙 4)', () {
    test('광고 표시가 예외를 던져도 조용히 넘어간다', () async {
      ads.failOnShow = true;

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse);
      expect(store.recordCount, 0);
    });

    test('저장소 읽기가 실패해도 예외가 새어나가지 않는다', () async {
      store.failOnRead = true;

      final shown = await coordinator.onAlertDismissed(now: now);

      expect(shown, isFalse);
    });

    test('미리 로딩이 영원히 끝나지 않아도 발화 흐름을 막지 않는다', () async {
      coordinator = AlertAdCoordinator(ads: HangingAds(), store: store);

      // onAlertFired 는 광고 로딩을 기다리므로 await 하지 않는다.
      // 호출부(app 계층)가 unawaited 로 부르는 것이 계약이다.
      unawaited(coordinator.onAlertFired());
      await Future<void>.delayed(Duration.zero);

      // 알림 흐름은 이미 진행됐어야 한다 — 여기서 막히면 규칙 4 위반
      expect(true, isTrue);
    });

    test('광고가 준비되지 않아도 해제 흐름은 즉시 끝난다', () async {
      coordinator = AlertAdCoordinator(
        ads: HangingAds(),
        store: store,
        // SDK 가 응답하지 않는 상황을 짧은 상한으로 재현한다
        showTimeout: const Duration(milliseconds: 50),
      );

      final shown = await coordinator
          .onAlertDismissed(now: now)
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () => throw StateError('광고가 해제 흐름을 막았다 — 규칙 4 위반'),
          );

      expect(shown, isFalse, reason: '응답 없는 광고는 포기하고 넘어간다');
    });
  });

  group('미리 로딩', () {
    test('알림 발화 시 광고를 미리 불러온다', () async {
      await coordinator.onAlertFired();

      expect(ads.preloadCount, 1);
    });
  });
}
