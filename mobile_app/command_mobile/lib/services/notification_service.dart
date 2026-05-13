import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'socket_service.dart';
import 'assignment_service.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase background init error: $e');
  }
  print("Handling a background message: ${message.messageId}");
}

class NotificationService extends ChangeNotifier {
  NotificationService._internal() {
    _init();
  }

  static final NotificationService instance = NotificationService._internal();

  final List<Map<String, dynamic>> _notifications = [];
  final Set<String> _processedIds = {};
  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  StreamSubscription? _socketSub;
  StreamSubscription? _assignmentSub;
  StreamSubscription? _alertSub;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> _init() async {
    // 1. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    // Create Android Notification Channel (Required for some Android versions)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'dmc_alerts_channel',
      'DMC Alerts',
      description: 'Notifications for disaster alerts and assignments',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Notification tapped: ${response.payload}');
      },
    );

    // 2. Initialize Firebase Messaging (if possible)
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      final messaging = FirebaseMessaging.instance;
      
      // Request permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('🔔 Notification Permission Status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        print('🔔 FCM Token: $token');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 Foreground FCM Message: ${message.notification?.title}');
        if (message.notification != null) {
          showLocalNotification(
            title: message.notification!.title ?? 'New Message',
            body: message.notification!.body ?? '',
            payload: message.data.toString(),
          );
        }
      });
    } catch (e) {
      print('⚠️ Firebase Messaging init error: $e');
    }

    _isInitialized = true;

    // Load historical notifications
    loadNotifications();

    // Listen for Socket.IO notifications
    _socketSub = SocketService.instance.onNotification.listen((data) {
      print('🔔 Socket Notification Received: $data');
      final id = data['id']?.toString() ?? data['notificationId']?.toString() ?? '';
      if (id.isNotEmpty && _processedIds.contains(id)) return;
      if (id.isNotEmpty) _processedIds.add(id);
      
      addNotification(data);
      
      showLocalNotification(
        title: data['title']?.toString() ?? 'New Notification',
        body: data['message']?.toString() ?? data['body']?.toString() ?? '',
      );
    });

    _alertSub = SocketService.instance.onAlert.listen((data) {
      print('🔔 Socket Alert Received: ${data['event']}');
      final event = data['event'] ?? '';
      if (event == 'alert:created' || event == 'publicAlert:created') {
        final alertId = data['alertId']?.toString() ?? '';
        final updatedAt = data['updatedAt']?.toString() ?? '';
        final dedupeId = 'alert:$alertId:$updatedAt';

        if (alertId.isNotEmpty && _processedIds.contains(dedupeId)) return;
        if (dedupeId.isNotEmpty) _processedIds.add(dedupeId);

        final title = data['title']?.toString() ?? 'New Alert';
        final severity = data['severity']?.toString() ?? 'NORMAL';
        final type = event == 'publicAlert:created' ? 'PUBLIC ALERT' : (data['type']?.toString() ?? 'ALERT');
        final message = data['message']?.toString() ?? 'A new $severity $type was issued.';

        addNotification({
          'title': title,
          'message': message,
          'type': type,
          'severity': severity,
          'createdAt': updatedAt.isNotEmpty ? updatedAt : DateTime.now().toIso8601String(),
        });

        showLocalNotification(
          title: title,
          body: message,
          payload: 'alert:$alertId',
        );
      }
    });

    // Also listen for resource and assignment events to show as notifications
    _assignmentSub = SocketService.instance.onAssignmentUpdate.listen((data) {
      print('🔔 Socket Assignment Event: ${data['event']}');
      final type = data['type'] ?? 'Assignment';
      final event = data['event'] ?? '';
      
      String? title;
      String? message;
      String? dedupeId;
      final role = AuthService.currentUser?.role ?? 'FIELD_OFFICER';
      final isFieldOfficer = role == 'FIELD_OFFICER';
      final isLogisticsStaff = role == 'LOGISTICS_STAFF';

      if (data.containsKey('requestId') && isFieldOfficer) {
        final status = data['status']?.toString().toUpperCase() ?? 'PENDING';
        final updatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString() ?? '';
        dedupeId = 'res:${data['requestId']}:$event:$status:$updatedAt';
        
        if (dedupeId.isNotEmpty && _processedIds.contains(dedupeId)) return;
        _processedIds.add(dedupeId);

        title = 'Resource Request';
        if (event == 'resourceRequest:deleted') {
          message = 'Request ${data['requestId']} was cancelled/removed';
        } else if (event == 'resourceRequest:created') {
          message = 'New request ${data['requestId']} submitted';
        } else if (status == 'IGNORED') {
          message = 'Resource request ignored for ${data['requestId']}';
        } else {
          message = 'Request ${data['requestId']} is now $status';
        }
      } else if (data.containsKey('deploymentId') && (isFieldOfficer || isLogisticsStaff || AuthService.currentUser?.role == 'RESPONSE_TEAM_MEMBER')) {
        final status = data['status']?.toString().toUpperCase() ?? 'PENDING';
        final updatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString() ?? '';
        dedupeId = 'dep:${data['deploymentId']}:$event:$status:$updatedAt';

        if (dedupeId.isNotEmpty && _processedIds.contains(dedupeId)) return;
        _processedIds.add(dedupeId);

        title = 'Assigned Resources';
        if (status == 'DEPLOYED') {
          message = 'Resources are Deployed for Incident ${data['incidentId'] ?? ''}'.trim();
        } else if (status == 'DELIVERED') {
          message = 'Resources were delivered for Incident ${data['incidentId'] ?? ''}'.trim();
        } else if (status.isNotEmpty) {
          message = 'Deployment ${data['deploymentId']} is now $status';
        } else {
          message = 'Resource deployment ${data['deploymentId']} was updated';
        }
      } else if (data.containsKey('assignmentId')) {
        final status = data['status']?.toString().toUpperCase() ?? 'ACTIVE';
        final updatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString() ?? '';
        dedupeId = 'asgn:${data['assignmentId']}:$event:$status:$updatedAt';
        
        if (dedupeId.isNotEmpty && _processedIds.contains(dedupeId)) return;
        _processedIds.add(dedupeId);

        title = 'Personnel Assignment';
        if (event == 'assignment:deleted' || event == 'incident:removed') {
          title = 'Assignment Removed';
          message = 'You have been unassigned from Incident ${data['incidentId']}';
        } else if (event == 'assignment:created' || event == 'incident:assigned') {
          title = 'New Assignment';
          final role = data['role']?.toString() ?? 'Responder';
          message = 'You have been assigned to Incident ${data['incidentId']} as $role';
        } else {
          message = 'Assignment ${data['assignmentId']} is now $status';
        }
      } else if (data.containsKey('incidentId')) {
        print('📌 NotificationService: Processing incident-related event: $event for ${data['incidentId']}');
        final status = data['status']?.toString().toUpperCase() ?? '';
        final updatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString() ?? '';
        dedupeId = 'inc:${data['incidentId']}:$event:$status:$updatedAt';
        
        if (dedupeId.isNotEmpty && _processedIds.contains(dedupeId)) {
          print('♻️ NotificationService: Deduplicated event: $dedupeId');
          return;
        }
        _processedIds.add(dedupeId);

        title = 'Incident Update';
        if (status.isNotEmpty) {
          message = 'Incident ${data['incidentId']} status changed to $status';
        } else {
          message = 'Incident ${data['incidentId']} data was updated';
        }
      }

      if (title != null) {
        addNotification({
          'title': title,
          'message': message,
          'type': type,
          'createdAt': data['updatedAt'] ?? DateTime.now().toIso8601String(),
          'incidentId': data['incidentId'],
        });

        showLocalNotification(
          title: title!,
          body: message ?? '',
          payload: data['incidentId'] != null ? 'incident:${data['incidentId']}' : null,
        );
      }
    });
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'dmc_alerts_channel',
      'DMC Alerts',
      channelDescription: 'Notifications for disaster alerts and assignments',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecond, // Unique ID
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  void addNotification(Map<String, dynamic> notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    try {
      final historical = await AssignmentService.fetchNotifications();
      for (final n in historical) {
        final id = n['notificationId']?.toString() ?? n['id']?.toString() ?? '';
        if (id.isNotEmpty && _processedIds.contains(id)) continue;
        if (id.isNotEmpty) _processedIds.add(id);
        
        _notifications.add(n);
      }
      // Sort by date if possible (backend already sorts, but just in case)
      _notifications.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      
      if (_notifications.length > 50) {
        _notifications.removeRange(50, _notifications.length);
      }
      notifyListeners();
    } catch (e) {
      print('❌ NotificationService: Failed to load historical notifications: $e');
    }
  }

  void clearNotifications() {
    _notifications.clear();
    _processedIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _assignmentSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }
}
