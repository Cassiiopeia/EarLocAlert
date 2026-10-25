import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/pro_purchase_service.dart';
import 'play_pro_purchase_service.dart';
import 'store_kit_pro_purchase_service.dart';

part 'pro_purchase_providers.g.dart';

/// 평생 이용권 결제 창구: Android > Play (#294), iOS > App Store (#298), 그 외 > 없음
@Riverpod(keepAlive: true)
ProPurchaseService proPurchaseService(Ref ref) {
  if (Platform.isAndroid) {
    final service = PlayProPurchaseService();
    ref.onDispose(service.dispose);
    return service;
  }
  if (Platform.isIOS) {
    final service = StoreKitProPurchaseService();
    ref.onDispose(service.dispose);
    return service;
  }
  return const NoopProPurchaseService();
}
