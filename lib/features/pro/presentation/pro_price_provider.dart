import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/pro_purchase_providers.dart';

part 'pro_price_provider.g.dart';

/// 평생 이용권 현지화 가격 (#294). null = 상품을 읽지 못함 — 화면이 열릴 때마다 다시 시도
@riverpod
Future<String?> proPrice(Ref ref) =>
    ref.watch(proPurchaseServiceProvider).loadPrice();
