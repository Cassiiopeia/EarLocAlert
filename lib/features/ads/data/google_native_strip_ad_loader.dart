import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_unit_ids.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../domain/native_strip_ad_loader.dart';

/// `google_mobile_ads` 네이티브 + 앱 팩토리 [factoryId] 로 띠 광고 로드
///
/// 로드: 단위 ID 확인 > 요청 > 성공 대기 (시간 초과 [_loadTimeout])
/// 네이티브 레이아웃이 에셋을 그대로 그린다 (Kotlin·Swift 는 소리를 내지 않는다).
class GoogleNativeStripAdLoader implements NativeStripAdLoader {
  GoogleNativeStripAdLoader({String Function()? resolveUnitId})
    : _resolveUnitId = resolveUnitId ?? (() => AdUnitIds.nativeStrip);

  // MainActivity.kt 의 registerNativeAdFactory · AppDelegate.swift 의 등록 ID 와 같은 값
  static const factoryId = 'earLocAlertStrip';

  // customOptions 키: StripNativeAdFactory.kt · StripNativeAdFactory.swift 와 같은 값
  static const backgroundColorKey = 'backgroundColor';
  static const headlineColorKey = 'headlineColor';
  static const callToActionColorKey = 'callToActionColor';
  static const badgeBackgroundColorKey = 'badgeBackgroundColor';
  static const badgeTextColorKey = 'badgeTextColor';
  static const badgeLabelKey = 'badgeLabel';

  /// 광고 표시 배지 문구 (정책상 필수)
  static const badgeLabel = 'AD';

  // 이 시간 안에 안 오면 포기 > 띠 없음
  static const _loadTimeout = Duration(seconds: 20);

  final String Function() _resolveUnitId;

  @override
  Future<LoadedNativeStripAd?> load(NativeStripAdColors colors) async {
    final unitId = _resolveUnitId();
    if (unitId.isEmpty) {
      // 운영 단위를 콘솔에서 만들기 전 — 요청하지 않는다
      Diagnostics.log('ads', 'native strip skipped reason=no_unit_id');
      return null;
    }

    NativeAd? nativeAd;
    try {
      final loadCompleter = Completer<NativeAd?>();
      nativeAd = NativeAd(
        adUnitId: unitId,
        request: const AdRequest(),
        factoryId: factoryId,
        customOptions: customOptionsOf(colors),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!loadCompleter.isCompleted) {
              loadCompleter.complete(ad as NativeAd);
            }
          },
          onAdFailedToLoad: (_, error) {
            // 사유를 남긴다 — 광고가 안 뜨는 이유의 유일한 단서다
            Diagnostics.log(
              'ads',
              'native strip failed code=${error.code} message=${error.message}',
            );
            // 해제는 아래 null 경로 한 곳에서 (실패·시간 초과 공통)
            if (!loadCompleter.isCompleted) loadCompleter.complete(null);
          },
        ),
      );
      await nativeAd.load();
      final loadedAd = await loadCompleter.future.timeout(
        _loadTimeout,
        onTimeout: () {
          Diagnostics.log('ads', 'native strip failed reason=timeout');
          return null;
        },
      );
      if (loadedAd == null) {
        await nativeAd.dispose();
        return null;
      }
      Diagnostics.log('ads', 'native strip loaded');
      return GoogleLoadedNativeStripAd(loadedAd);
    } on Object catch (error) {
      // 광고는 보조 요소 > 사용자 알림 없이 기록만
      Diagnostics.log('ads', 'native strip load error $error');
      await nativeAd?.dispose();
      return null;
    }
  }

  /// 띠 색 > 팩토리 옵션 (색은 ARGB 정수)
  static Map<String, Object> customOptionsOf(NativeStripAdColors colors) => {
    backgroundColorKey: colors.background,
    headlineColorKey: colors.headline,
    callToActionColorKey: colors.callToAction,
    badgeBackgroundColorKey: colors.badgeBackground,
    badgeTextColorKey: colors.badgeText,
    badgeLabelKey: badgeLabel,
  };
}

/// 로드된 [NativeAd] 를 쥔 띠 광고 — 화면은 [nativeAd] 를 `AdWidget` 으로 그린다
class GoogleLoadedNativeStripAd implements LoadedNativeStripAd {
  GoogleLoadedNativeStripAd(this.nativeAd);

  final NativeAd nativeAd;

  @override
  void dispose() => unawaited(nativeAd.dispose());
}
