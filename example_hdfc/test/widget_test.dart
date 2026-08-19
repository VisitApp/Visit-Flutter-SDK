import 'package:flutter_test/flutter_test.dart';

import 'package:visit_flutter_sdk_hdfc_example/main.dart';

void main() {
  testWidgets('requires an SSO URL before launching the SDK', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HdfcCompatibilityApp());

    await tester.tap(find.text('Open Visit SDK'));
    await tester.pump();

    expect(find.text('Please enter an SSO URL.'), findsOneWidget);
  });
}
