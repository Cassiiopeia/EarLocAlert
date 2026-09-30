import '../core/diagnostics/diagnostics.dart';
import '../features/ads/domain/ad_frequency_policy.dart';
import '../features/ads/domain/ad_frequency_store.dart';
import '../features/ads/domain/interstitial_ad_service.dart';

/// 알림과 광고를 잇는 조율 계층 (docs/02-ARCHITECTURE.md 규칙 1·4)
///
/// **`alert` 는 `ads` 를 import 하지 않는다.** feature 간 협력은 여기서
/// 처리한다. 그래서 알림 흐름을 광고 없이 테스트할 수 있다.
///
/// 이 클래스의 계약:
/// - 광고는 **해제가 끝난 뒤에만** 시도된다
/// - 광고 실패는 어떤 형태로도 위로 전파되지 않는다
class AlertAdCoordinator {
  AlertAdCoordinator({
    required InterstitialAdService ads,
    required AdFrequencyStore store,
    AdFrequencyPolicy policy = const AdFrequencyPolicy(),
    Duration showTimeout = const Duration(seconds: 3),
  }) : _ads = ads,
       _store = store,
       _policy = policy,
       _showTimeout = showTimeout;

  final InterstitialAdService _ads;
  final AdFrequencyStore _store;
  final AdFrequencyPolicy _policy;

  /// 광고 SDK 가 응답하지 않을 때 기다릴 상한.
  ///
  /// 해제는 이미 끝난 뒤라 알림 자체는 안전하지만, 여기서 무한정 기다리면
  /// 화면 전환이 멈춘 것처럼 보인다.
  final Duration _showTimeout;

  /// 알림이 발화할 때 호출한다.
  ///
  /// 사용자가 해제할 때쯤 광고가 준비되어 있게 미리 불러둔다.
  /// **실패해도 아무 일도 일어나지 않는다.**
  Future<void> onAlertFired() async {
    try {
      await _ads.preload();
    } on Object catch (error) {
      // 미리 로딩 실패는 무시한다 — 광고가 없으면 그냥 안 보여주면 된다.
      // 다만 기록은 남긴다 (이슈 #127): 광고가 계속 안 뜨는 이유를
      // 나중에 물어보면 이 줄이 유일한 단서다
      Diagnostics.log('ads', 'preload failed $error');
    }
  }

  /// 해제가 **완료된 뒤** 호출한다.
  ///
  /// 이 메서드를 해제 전에 부르거나 `await` 로 해제를 막으면
  /// 규칙 4 위반이다.
  ///
  /// 광고를 실제로 보여줬으면 `true`.
  Future<bool> onAlertDismissed({required DateTime now}) async {
    try {
      final state = await _store.read();
      if (state.isFirstLaunch) {
        // 첫 해제에서는 광고를 내지 않고 "첫 실행 끝" 표시만 남긴다 — 첫인상을
        // 광고로 만들지 않는다. 이 표시를 남기는 곳이 없어서 예전에는 광고가 영원히
        // 나오지 않았다 (이슈 #175). 이미 해제가 끝난 뒤라 사용자에게 영향이 없다.
        await _store.markLaunched();
        Diagnostics.log('ads', 'interstitial skipped (reason=first_launch)');
        return false;
      }
      final allowed = _policy.canShowInterstitial(
        now: now,
        lastShownAt: state.lastShownAt,
        shownToday: state.shownToday,
        isFirstLaunch: state.isFirstLaunch,
      );
      if (!allowed) {
        // **빈도 제한에 걸린 것과 광고가 없어서 못 띄운 것은 다르다**
        // (이슈 #127). 로그가 없으면 "왜 광고가 안 나오나"에 답할 수 없다
        Diagnostics.log(
          'ads',
          'interstitial skipped (reason=frequency_limit shown_today=${state.shownToday} '
              'last_shown=${state.lastShownAt?.toIso8601String() ?? "none"})',
        );
        return false;
      }

      final shown = await _ads.showIfReady().timeout(
        _showTimeout,
        onTimeout: () => false,
      );
      if (shown) {
        await _store.recordShown(now);
        Diagnostics.log('ads', 'interstitial shown');
      } else {
        Diagnostics.log(
          'ads',
          'interstitial skipped (reason=not_ready_or_timeout)',
        );
      }
      return shown;
    } on Object catch (error) {
      // 저장소·광고 어느 쪽이 실패해도 조용히 넘어간다.
      // 사용자는 이미 알림을 껐고, 그것이 이 흐름의 목적이었다.
      Diagnostics.log('ads', 'interstitial failed $error');
      return false;
    }
  }
}
