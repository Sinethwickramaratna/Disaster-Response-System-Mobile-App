import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/login_screen.dart';
import 'package:command_mobile/services/auth_service.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);
  setUp(AuthService.signOut);

  group('LoginScreen', () {
    testWidgets('renders login UI elements', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const LoginScreen()));

      expect(find.text('COMMAND'), findsOneWidget);
      expect(find.text('SECURE ACCESS PORTAL'), findsOneWidget);
      expect(find.text('SERVICE ID'), findsOneWidget);
      expect(find.text('SECURE PASSKEY'), findsOneWidget);
      expect(find.text('INITIALIZE SESSION'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('accepts service id and passkey input', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const LoginScreen()));

      await tester.enterText(
        find.widgetWithText(TextField, 'Enter ID (e.g., CMD-049)'),
        'CMD-049',
      );
      await tester.enterText(find.byType(TextField).at(1), 'command123');

      expect(find.text('CMD-049'), findsOneWidget);
      expect(find.text('command123'), findsOneWidget);
    });

    testWidgets('shows error when fields are empty', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const LoginScreen()));

      await tester.tap(find.text('INITIALIZE SESSION'));
      await tester.pump();

      expect(find.text('Please enter both Service ID and Passkey'), findsOneWidget);
    });

    testWidgets('shows invalid credentials message', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const LoginScreen()));

      await tester.enterText(
        find.widgetWithText(TextField, 'Enter ID (e.g., CMD-049)'),
        'CMD-049',
      );
      await tester.enterText(find.byType(TextField).at(1), 'bad-pass');
      await tester.tap(find.text('INITIALIZE SESSION'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Invalid credentials. Access denied.'), findsOneWidget);
    });

    testWidgets('toggles passkey visibility icon', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const LoginScreen()));

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('successful login opens dashboard', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          home: const LoginScreen(),
          initialRoute: '/',
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Enter ID (e.g., CMD-049)'),
        'CMD-049',
      );
      await tester.enterText(find.byType(TextField).at(1), 'command123');
      await tester.tap(find.text('INITIALIZE SESSION'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);
    });
  });
}
