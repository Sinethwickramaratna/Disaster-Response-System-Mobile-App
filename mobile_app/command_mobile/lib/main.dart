import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/login_screen.dart';
import 'package:command_mobile/screens/alerts_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/screens/resources_screen.dart';
import 'package:command_mobile/theme/app_theme.dart';
import 'package:command_mobile/services/auth_service.dart';

import 'package:command_mobile/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AuthService.initializeSession();

  final hasToken = await AuthService.hasValidToken();
  if (hasToken) {
    // Pre-load notifications for returning users
    NotificationService.instance.loadNotifications();
  }
  
  final initialRoute = hasToken ? '/dashboard' : '/login';

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disaster Response',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/map': (context) => const MapScreen(),
        '/resources': (context) => const ResourcesScreen(),
        '/alerts': (context) => const AlertsScreen(),
      },
    );
  }
}


