/// 평생 이용권 구매 기록: 주문 번호, 구매 시각 (#294)
/// 이용권 정보 시트 표시·문의 대응용. 계정 이메일은 Play 가 앱에 주지 않아 없음
class ProPurchaseRecord {
  const ProPurchaseRecord({this.orderId, this.purchasedAt});

  /// Play 주문 번호 (GPA.xxxx-xxxx-xxxx-xxxxx)
  final String? orderId;

  /// 구매 시각 (UTC)
  final DateTime? purchasedAt;
}
