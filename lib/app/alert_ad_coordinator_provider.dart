import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/ads/data/ads_providers.dart';
import 'alert_ad_coordinator.dart';

part 'alert_ad_coordinator_provider.g.dart';

/// 알림과 광고를 잇는 조율자 (docs/02-ARCHITECTURE.md 규칙 1)
///
/// 조율자는 app 계층에 있으니 provider 도 app 에 둔다 — 예전엔 ads 기능이
/// app 을 거꾸로 import 했다 (아키텍처 검수 #276)
@Riverpod(keepAlive: true)
Future<AlertAdCoordinator> alertAdCoordinator(Ref ref) async {
  return AlertAdCoordinator(
    ads: ref.watch(interstitialAdServiceProvider),
    store: await ref.watch(adFrequencyStoreProvider.future),
  );
}
