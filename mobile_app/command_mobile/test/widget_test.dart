import 'package:flutter_test/flutter_test.dart';

import 'package:command_mobile/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the login screen loads with expected elements
    expect(find.text('COMMAND'), findsOneWidget);
  });
}
