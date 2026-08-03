import 'package:ear_loc_alert/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱이 크래시 없이 뜬다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EarLocAlertApp()));
    await tester.pump();

    // 권한 조회는 플랫폼 채널이라 테스트 환경에서 완료되지 않는다.
    // 여기서 확인하는 것은 위젯 트리가 예외 없이 구성되는지다.
    expect(tester.takeException(), isNull);
  });
}
