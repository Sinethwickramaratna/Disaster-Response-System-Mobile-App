import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/screens/resources_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);

  group('DashboardScreen', () {
    testWidgets('renders dashboard metrics and telemetry', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      expect(find.text('OPERATIONS'), findsOneWidget);
      expect(find.text('CRITICAL ALERTS'), findsOneWidget);
      expect(find.text('ACTIVE INCIDENTS'), findsOneWidget);
      expect(find.text('RESOURCE READINESS'), findsOneWidget);
      expect(find.text('NATIONAL STATUS'), findsOneWidget);
      expect(find.text('LATEST TELEMETRY'), findsOneWidget);
      expect(find.text('Geo-Visualization Active'), findsOneWidget);
    });

    testWidgets('drawer opens and shows menu items', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD'), findsWidgets);
      expect(find.text('REPORTS'), findsWidgets);
      expect(find.text('MAP'), findsWidgets);
      expect(find.text('RESOURCES'), findsWidgets);
      expect(find.text('ALERTS'), findsWidgets);
      expect(find.text('LOGOUT'), findsOneWidget);
    });

    testWidgets('bottom navigation opens reports screen', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      await tester.tap(find.text('REPORTS').last);
      await tester.pumpAndSettle();

      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('Field Reports'), findsOneWidget);
    });

    testWidgets('bottom navigation opens map screen', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      await tester.tap(find.text('MAP').last);
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('MATRIX'), findsOneWidget);
    });

    testWidgets('bottom navigation opens resources screen', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      await tester.tap(find.text('RESOURCES').last);
      await tester.pumpAndSettle();

      expect(find.byType(ResourcesScreen), findsOneWidget);
      expect(find.text('CAPACITY OVERVIEW'), findsOneWidget);
    });

    testWidgets('bottom navigation opens alerts screen', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const DashboardScreen()));

      await tester.tap(find.text('ALERTS').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertsScreen), findsOneWidget);
      expect(find.text('Active Alerts'), findsOneWidget);
    });
  });
}
