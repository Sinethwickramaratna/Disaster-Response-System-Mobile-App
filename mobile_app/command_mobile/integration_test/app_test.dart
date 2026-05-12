import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import your app's `main.dart`. Adjust the package name if different.
import 'package:command_mobile/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full user flow: Login -> Dashboard -> Map', (WidgetTester tester) async {
    // Launch the app
    app.main();
    await tester.pumpAndSettle();

    // NOTE: The test uses Keys and text labels that should exist in the app.
    // If your widgets use different keys/labels, update the finders below.

    // 1) Ensure we're on the Login screen (either the initial route or navigated)
    final emailField = find.byKey(const Key('emailField'));
    final passwordField = find.byKey(const Key('passwordField'));
    final loginButton = find.byKey(const Key('loginButton'));

    // Wait until the login form appears (timeout after ~10 seconds)
    await _waitFor(tester, emailField);

    // 2) Enter valid input into fields
    await tester.enterText(emailField, 'officer@example.com');
    await tester.enterText(passwordField, 'Password123');
    await tester.pumpAndSettle();

    // 3) Tap on the Login button
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // 4) Wait for navigation to Dashboard
    final dashboardTitle = find.byKey(const Key('dashboardTitle'));
    await _waitFor(tester, dashboardTitle);

    // 5) Verify expected result: Dashboard visible with welcome text
    expect(dashboardTitle, findsOneWidget);
    // Use a predicate finder to match Text widgets that contain 'Welcome'
    final welcomeFinder = find.byWidgetPredicate((widget) {
      if (widget is Text) {
        final data = widget.data ?? '';
        return data.contains('Welcome');
      }
      return false;
    });
    expect(welcomeFinder, findsWidgets);

    // 6) Navigate to Map screen (tap Map button)
    final mapButton = find.byKey(const Key('mapButton'));
    await tester.tap(mapButton);
    await tester.pumpAndSettle();

    // 7) Verify Map screen shown
    final mapScreenTitle = find.byKey(const Key('mapScreenTitle'));
    await _waitFor(tester, mapScreenTitle);
    expect(mapScreenTitle, findsOneWidget);

    // Additional assertion: ensure at least one map marker or nearby incident is shown
    // (Adjust the finder to match your map marker widget or text)
    final incidentMarker = find.byKey(const Key('incidentMarker_0'));
    // Expect at least one incident marker; use findsOneWidget if you expect exactly one
    expect(incidentMarker, findsWidgets);
  });
}

/// Utility that pumps frames until [finder] is present or the timeout elapses.
Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Final pump and let the caller assert presence (so failures show in test output)
  await tester.pumpAndSettle();
}
