import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../data/pro_purchase_record_store.dart';
import '../domain/pro_purchase_record.dart';

part 'pro_purchase_record_controller.g.dart';

/// 구매 기록 (#294): 이용권 정보 시트가 읽고, 구매·복원·시작 조회가 저장
@Riverpod(keepAlive: true)
class ProPurchaseRecordController extends _$ProPurchaseRecordController {
  @override
  Future<ProPurchaseRecord?> build() => const ProPurchaseRecordStore().read();

  /// 저장 > 화면 갱신. 기록이 없으면(정보 없는 복원 결과) 그대로 둠
  Future<void> save(ProPurchaseRecord? record) async {
    if (record == null) return;
    try {
      await const ProPurchaseRecordStore().write(record);
      state = AsyncData(record);
      Diagnostics.log(
        'pro',
        'purchase record saved has_order=${record.orderId != null} '
            'purchased_at=${record.purchasedAt?.toIso8601String() ?? "none"}',
      );
    } on Object catch (error) {
      Diagnostics.log('pro', 'purchase record save failed error=$error');
    }
  }
}
