import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/components/app_drawer.dart';
import 'package:command_mobile/screens/login_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/services/auth_service.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);
  setUp(() {
    AuthService.signOut();
    AuthService.authenticate('FO-A01', 'zonea001');
  });

  testWidgets('renders session header and destinations', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const AppDrawer(currentRoute: '/dashboard')));

    expect(find.text('COMMAND'), findsOneWidget);
    expect(find.text('FO-A01'), findsOneWidget);
    expect(find.text('OFFICER / ZONE-A'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('REPORTS'), findsOneWidget);
    expect(find.text('LOGOUT'), findsOneWidget);
  });

  testWidgets('navigation destination opens its screen', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      buildTestApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: const AppDrawer(currentRoute: '/dashboard'),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('REPORTS'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportsScreen), findsOneWidget);
  });

  testWidgets('logout clears user and returns to login', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      buildTestApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: const AppDrawer(currentRoute: '/dashboard'),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOGOUT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(AuthService.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('selected destination is highlighted', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const AppDrawer(currentRoute: '/reports')));

    final reportsTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('REPORTS'),
        matching: find.byType(ListTile),
      ),
    );

    expect(reportsTile.selected, isTrue);
  });
}
