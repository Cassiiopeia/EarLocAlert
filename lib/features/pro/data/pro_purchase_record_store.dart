import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pro_purchase_record.dart';

/// 구매 기록 저장소 (SharedPreferences)
class ProPurchaseRecordStore {
  const ProPurchaseRecordStore();

  // prefs: Play 주문 번호
  static const String _orderIdKey = 'pro_purchase_order_id';

  // prefs: 구매 시각 (UTC epoch 밀리초)
  static const String _purchasedAtKey = 'pro_purchase_purchased_at_ms';

  Future<ProPurchaseRecord?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getString(_orderIdKey);
    final purchasedAtMilliseconds = prefs.getInt(_purchasedAtKey);
    if (orderId == null && purchasedAtMilliseconds == null) return null;
    return ProPurchaseRecord(
      orderId: orderId,
      purchasedAt: purchasedAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              purchasedAtMilliseconds,
              isUtc: true,
            ),
    );
  }

  Future<void> write(ProPurchaseRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = record.orderId;
    final purchasedAt = record.purchasedAt;
    if (orderId != null) await prefs.setString(_orderIdKey, orderId);
    if (purchasedAt != null) {
      await prefs.setInt(_purchasedAtKey, purchasedAt.millisecondsSinceEpoch);
    }
  }
}
