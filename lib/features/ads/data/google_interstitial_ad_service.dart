import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/ad_consent.dart';
import '../domain/ad_unit_ids.dart';
import '../domain/interstitial_ad_service.dart';

/// `google_mobile_ads` 기반 전면광고 구현
///
/// **이 클래스의 모든 메서드는 예외를 던지지 않는다.** 광고 실패가
/// 알림 흐름에 영향을 주면 안 되기 때문이다
/// (docs/02-ARCHITECTURE.md 규칙 4).
class GoogleInterstitialAdService implements InterstitialAdService {
  GoogleInterstitialAdService({required AdConsent consent})
    : _consent = consent;

  /// 동의를 받기 전에는 광고를 요청하지 않는다 (이슈 #166)
  final AdConsent _consent;

  InterstitialAd? _ad;
  bool _loading = false;

  @override
  bool get isReady => _ad != null;

  @override
  Future<void> preload() async {
    if (_ad != null || _loading) return;
    _loading = true;

    try {
      // **동의 없이 광고를 요청하지 않는다.** 유럽 경제 지역과 영국은 동의가 필요하고,
      // 모르면 요청하지 않는다. 다음 알림에서 다시 시도된다
      if (!await _consent.canRequestAds()) {
        Diagnostics.log('ads', 'preload skipped reason=consent_not_ready');
        _loading = false;
        return;
      }
      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loading = false;
          },
          onAdFailedToLoad: (error) {
            // 로딩 실패는 정상적으로 일어난다 — 네트워크 없음, 재고 없음 등.
            // 조용히 넘어간다. 다음 알림에서 다시 시도된다.
            _ad = null;
            _loading = false;
          },
        ),
      );
    } on Object {
      _loading = false;
    }
  }

  @override
  Future<bool> showIfReady() async {
    final ad = _ad;
    if (ad == null) return false;

    // 참조를 먼저 비운다 — 같은 광고를 두 번 보여주면 정책 위반이다
    _ad = null;

    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          // 다음 알림을 위해 미리 채워둔다
          preload();
        },
        onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
      );
      await ad.show();
      return true;
    } on Object {
      ad.dispose();
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _ad?.dispose();
    _ad = null;
  }
}
