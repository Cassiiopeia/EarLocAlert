// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/alert_ad_coordinator.dart';
import '../data/google_interstitial_ad_service.dart';
import '../data/prefs_ad_frequency_store.dart';
import '../domain/ad_frequency_store.dart';
import '../domain/interstitial_ad_service.dart';

part 'ads_providers.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

@Riverpod(keepAlive: true)
InterstitialAdService interstitialAdService(Ref ref) {
  final service = GoogleInterstitialAdService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
Future<AdFrequencyStore> adFrequencyStore(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PrefsAdFrequencyStore(prefs);
}

/// 알림과 광고를 잇는 조율자 (docs/02-ARCHITECTURE.md 규칙 1)
@Riverpod(keepAlive: true)
Future<AlertAdCoordinator> alertAdCoordinator(Ref ref) async {
  return AlertAdCoordinator(
    ads: ref.watch(interstitialAdServiceProvider),
    store: await ref.watch(adFrequencyStoreProvider.future),
  );
}
