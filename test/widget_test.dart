import 'package:ear_loc_alert/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱이 크래시 없이 뜬다', (tester) async {
    await tester.pumpWidget(const EarLocAlertApp());

    expect(find.text('EarLocAlert'), findsOneWidget);
  });
}
