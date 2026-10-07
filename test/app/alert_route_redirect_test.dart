import 'package:ear_loc_alert/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이슈 #222 — 해제 직후 세션이 비어도 해제 완료 화면을 덮지 않는다
void main() {
  test('알림 화면에 머물러 있으면 홈으로 돌린다', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.alert), isTrue);
  });

  test('해제 완료 화면으로 떠났으면 돌리지 않는다', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.alertDismissed), isFalse);
  });

  test('다른 화면이면 돌리지 않는다', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.home), isFalse);
  });
}
