import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/google_ad_consent.dart';
import '../data/google_interstitial_ad_service.dart';
import '../data/google_native_strip_ad_loader.dart';
import '../data/prefs_ad_frequency_store.dart';
import '../domain/ad_consent.dart';
import '../domain/ad_frequency_store.dart';
import '../domain/interstitial_ad_service.dart';
import '../domain/native_strip_ad_loader.dart';

part 'ads_providers.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

/// 광고 동의 (이슈 #166) — 유럽 경제 지역과 영국은 광고 요청 전에 동의가 필요하다
@Riverpod(keepAlive: true)
AdConsent adConsent(Ref ref) => const GoogleAdConsent();

@Riverpod(keepAlive: true)
InterstitialAdService interstitialAdService(Ref ref) {
  final service = GoogleInterstitialAdService(
    consent: ref.watch(adConsentProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
Future<AdFrequencyStore> adFrequencyStore(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PrefsAdFrequencyStore(prefs);
}

/// 하단 한 줄 네이티브 띠 로더 (이슈 #283)
@Riverpod(keepAlive: true)
NativeStripAdLoader nativeStripAdLoader(Ref ref) => GoogleNativeStripAdLoader();

/// 로드된 띠 광고 > 그릴 위젯 (구현체를 아는 곳은 이 조립 파일뿐 — 테스트는 가짜로 바꾼다)
@Riverpod(keepAlive: true)
Widget Function(LoadedNativeStripAd loadedAd) nativeStripAdViewBuilder(
  Ref ref,
) =>
    (loadedAd) =>
        AdWidget(ad: (loadedAd as GoogleLoadedNativeStripAd).nativeAd);
