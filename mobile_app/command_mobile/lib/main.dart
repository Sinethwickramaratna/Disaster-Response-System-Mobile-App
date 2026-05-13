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

import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  await AuthService.initializeSession();

  final hasToken = await AuthService.hasValidToken();
  if (hasToken) {
    // Pre-load notifications for returning users
    NotificationService.instance.loadNotifications();
  }
  
  final initialRoute = hasToken ? '/dashboard' : '/login';

  runApp(MyApp(initialRoute: initialRoute));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    NotificationService.instance.selectNotificationStream.listen((payload) {
      if (payload == null) return;
      
      print('🚀 Navigating via notification payload: $payload');
      
      if (payload == 'resources') {
        navigatorKey.currentState?.pushNamed('/resources');
      } else if (payload == 'reports') {
        navigatorKey.currentState?.pushNamed('/reports');
      } else if (payload.startsWith('alert:')) {
        navigatorKey.currentState?.pushNamed('/alerts');
      } else if (payload.startsWith('incident:')) {
        navigatorKey.currentState?.pushNamed('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC Sri Lanka',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: widget.initialRoute,
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
