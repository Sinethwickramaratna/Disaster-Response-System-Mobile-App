import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/login_screen.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/screens/resources_screen.dart';
import 'package:command_mobile/theme/app_theme.dart';

void configureTestFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

Widget buildTestApp({
  required Widget home,
  String initialRoute = '/',
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    initialRoute: initialRoute,
    routes: {
      '/': (_) => home,
      '/login': (_) => const LoginScreen(),
      '/dashboard': (_) => const DashboardScreen(),
      '/reports': (_) => const ReportsScreen(),
      '/map': (_) => const MapScreen(),
      '/resources': (_) => const ResourcesScreen(),
      '/alerts': (_) => const AlertsScreen(),
    },
  );
}
