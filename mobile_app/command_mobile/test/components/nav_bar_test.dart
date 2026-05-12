import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/components/nav_bar.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('renders all bottom navigation tabs', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: Scaffold(
          body: BottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('REPORTS'), findsOneWidget);
    expect(find.text('MAP'), findsOneWidget);
    expect(find.text('RESOURCES'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);
  });

  testWidgets('tapping each tab reports its index', (tester) async {
    final tapped = <int>[];

    await tester.pumpWidget(
      buildTestApp(
        home: Scaffold(
          body: BottomNav(currentIndex: 2, onTap: tapped.add),
        ),
      ),
    );

    await tester.tap(find.text('DASHBOARD'));
    await tester.tap(find.text('REPORTS'));
    await tester.tap(find.text('MAP'));
    await tester.tap(find.text('RESOURCES'));
    await tester.tap(find.text('ALERTS'));

    expect(tapped, [0, 1, 2, 3, 4]);
  });

  testWidgets('active tab has selected top border', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: Scaffold(
          body: BottomNav(currentIndex: 4, onTap: (_) {}),
        ),
      ),
    );

    final activeContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('ALERTS'), matching: find.byType(Container))
          .first,
    );
    final decoration = activeContainer.decoration! as BoxDecoration;

    expect(decoration.border, isNotNull);
  });
}
