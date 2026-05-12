import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/components/nav_bar.dart';
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/resources_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);

  group('ResourcesScreen', () {
    testWidgets('renders search, capacity cards, and active units', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ResourcesScreen()));

      expect(find.text('Search units, zones...'), findsOneWidget);
      expect(find.text('CAPACITY OVERVIEW'), findsOneWidget);
      expect(find.text('North Zone Shelter'), findsOneWidget);
      expect(find.text('South Zone Hub'), findsOneWidget);
      expect(find.text('ACTIVE UNITS'), findsOneWidget);
      expect(find.text('SLN Rapid Rescue'), findsOneWidget);
      expect(find.text('Medical Corps B'), findsOneWidget);
    });

    testWidgets('search field accepts text', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ResourcesScreen()));

      await tester.enterText(find.byType(TextField), 'medical');

      expect(find.text('medical'), findsOneWidget);
    });

    testWidgets('action buttons are visible', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ResourcesScreen()));

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);
      expect(find.text('Reroute Assets'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('renders both rescue and medical unit icon branches', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ResourcesScreen()));

      expect(find.byIcon(Icons.security), findsOneWidget);
      expect(find.byIcon(Icons.local_hospital), findsOneWidget);
      expect(find.text('ACTIVE SEARCH'), findsOneWidget);
      expect(find.text('IN TRANSIT'), findsOneWidget);
    });

    testWidgets('filter button can be pressed and bottom nav opens alerts', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ResourcesScreen()));

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();

      final nav = tester.widget<BottomNav>(find.byType(BottomNav));
      nav.onTap(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AlertsScreen), findsOneWidget);
    });
  });
}
