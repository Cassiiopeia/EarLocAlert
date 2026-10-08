import 'package:ear_loc_alert/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이슈 #222 — 해제 직후 세션이 비어도 해제 흐름이 옮긴 화면을 덮지 않는다.
/// 해제 완료 화면은 #233 에서 없앴다 — 이제 해제 흐름은 홈(미리보기면 설정)으로 간다
void main() {
  test('알림 화면에 머물러 있으면 홈으로 돌린다', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.alert), isTrue);
  });

  test('해제 흐름이 홈으로 옮겼으면 돌리지 않는다', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.home), isFalse);
  });

  test('미리보기가 설정으로 돌아갔으면 덮지 않는다 (이슈 #229)', () {
    expect(shouldLeaveEmptyAlertRoute(AppRoutes.settings), isFalse);
  });
}
