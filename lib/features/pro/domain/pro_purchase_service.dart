import 'pro_purchase_record.dart';

/// 평생 이용권 결제 결과 (#294)
sealed class ProPurchaseEvent {
  const ProPurchaseEvent();
}

/// 구매 완료 (구매 확인까지 끝남)
final class ProPurchased extends ProPurchaseEvent {
  const ProPurchased(this.record);

  final ProPurchaseRecord? record;
}

/// 복원으로 보유가 확인됨
final class ProRestored extends ProPurchaseEvent {
  const ProRestored(this.record);

  final ProPurchaseRecord? record;
}

/// 결제 대기 (편의점 결제 등) — 프로로 열지 않음
final class ProPurchasePending extends ProPurchaseEvent {
  const ProPurchasePending();
}

/// 사용자가 결제를 취소
final class ProPurchaseCancelled extends ProPurchaseEvent {
  const ProPurchaseCancelled();
}

final class ProPurchaseFailed extends ProPurchaseEvent {
  const ProPurchaseFailed(this.reason);

  /// 로그용 사유 (스토어 오류 코드)
  final String reason;
}

/// 결제를 맡는 스토어 (#298). 스토어마다 다른 화면 요소(코드 사용·구매 계정 안내)를 가림
enum ProPurchaseStore { googlePlay, appStore, none }

/// 평생 이용권 결제 창구: 가격 조회, 구매, 복원, 보유 확인
abstract interface class ProPurchaseService {
  /// 결제를 맡는 스토어
  ProPurchaseStore get store;

  /// 구매·복원 결과. 앱 시작 직후부터 구독해야 지난 실행의 결제도 받음
  Stream<ProPurchaseEvent> get events;

  /// 현지화 가격 문자열. null = 상품을 읽지 못함(스토어 연결 실패·상품 미등록)
  Future<String?> loadPrice();

  /// 결제 창을 띄웠으면 true. 결과는 [events] 로 옴
  Future<bool> buy();

  /// 계정이 상품을 보유하는가 (복원·시작 시 확인). 미확인 구매는 여기서 마저 확인
  /// null = 조회 실패(상태를 바꾸지 말라는 신호)
  Future<bool?> hasOwnedPurchase();

  /// 마지막 보유 조회에서 찾은 구매 기록. 조회 전·미보유면 null
  ProPurchaseRecord? get ownedRecord;
}
