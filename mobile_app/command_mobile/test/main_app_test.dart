import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/main.dart' as app;
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/login_screen.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/screens/resources_screen.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('app starts on login route', (tester) async {
    await tester.pumpWidget(const app.MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('COMMAND'), findsOneWidget);
  });

  testWidgets('theme and title are configured', (tester) async {
    await tester.pumpWidget(const app.MyApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.title, 'Disaster Response');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
    expect(materialApp.theme, isNotNull);
    expect(materialApp.initialRoute, '/login');
  });

  testWidgets('all named routes build the expected screens', (tester) async {
    await tester.pumpWidget(const app.MyApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final routes = materialApp.routes!;
    final context = tester.element(find.byType(LoginScreen));

    expect(routes.keys, containsAll([
      '/login',
      '/dashboard',
      '/reports',
      '/map',
      '/resources',
      '/alerts',
    ]));
    expect(routes['/login']!(context), isA<LoginScreen>());
    expect(routes['/dashboard']!(context), isA<DashboardScreen>());
    expect(routes['/reports']!(context), isA<ReportsScreen>());
    expect(routes['/map']!(context), isA<MapScreen>());
    expect(routes['/resources']!(context), isA<ResourcesScreen>());
    expect(routes['/alerts']!(context), isA<AlertsScreen>());
  });

  testWidgets('navigator can move from login route to dashboard route', (tester) async {
    await tester.pumpWidget(const app.MyApp());

    Navigator.of(tester.element(find.byType(LoginScreen))).pushNamed('/dashboard');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('OPERATIONS'), findsOneWidget);
  });

  testWidgets('main bootstraps the app widget tree', (tester) async {
    app.main();
    await tester.pump();

    expect(find.byType(app.MyApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
