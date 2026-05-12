import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);

  group('AlertsScreen', () {
    testWidgets('renders alerts list and system status', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AlertsScreen()));

      expect(find.text('Active Alerts'), findsOneWidget);
      expect(find.text('3 CRITICAL'), findsOneWidget);
      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('Level 3 Flood Warning: Sector Alpha'), findsOneWidget);
      expect(find.text('Grid Failure: Communications Hub 4'), findsOneWidget);
      expect(find.text('Supply Line Disruption Route 66'), findsOneWidget);
      expect(find.text('Shift Handover Completed'), findsOneWidget);
    });

    testWidgets('alert card exposes view details action', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AlertsScreen()));

      expect(find.text('VIEW DETAILS'), findsNWidgets(3));
      expect(find.text('CRITICAL'), findsNWidgets(2));
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('ROUTINE'), findsOneWidget);
    });

    testWidgets('drawer opens from alerts screen', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AlertsScreen()));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('ALERTS'), findsWidgets);
      expect(find.text('DASHBOARD'), findsWidgets);
    });

    testWidgets('bottom navigation can open dashboard', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AlertsScreen()));

      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);
    });
  });
}
