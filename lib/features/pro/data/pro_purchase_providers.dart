import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/pro_purchase_service.dart';
import 'play_pro_purchase_service.dart';

part 'pro_purchase_providers.g.dart';

/// 평생 이용권 결제 창구 (#294). Android 만 Play 결제, 그 외는 아무것도 안 함
@Riverpod(keepAlive: true)
ProPurchaseService proPurchaseService(Ref ref) {
  if (!Platform.isAndroid) return const NoopProPurchaseService();
  final service = PlayProPurchaseService();
  ref.onDispose(service.dispose);
  return service;
}
