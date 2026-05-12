import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._internal() {
    _init();
  }

  static final NotificationService instance = NotificationService._internal();

  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  StreamSubscription? _socketSub;

  void _init() {
    _socketSub = SocketService.instance.onNotification.listen((data) {
      addNotification(data);
    });

    // Also listen for resource and assignment events to show as notifications
    SocketService.instance.onAssignmentUpdate.listen((data) {
      final event = data['event'] ?? 'Update';
      final type = data['type'] ?? 'Assignment';
      
      // Map some events to friendly notifications
      String? title;
      String? message;

      if (data.containsKey('requestId')) {
        title = 'Resource Request';
        message = 'Request ${data['requestId']} was ${data['status'] ?? 'processed'}';
      } else if (data.containsKey('incidentId')) {
        title = 'Incident Update';
        message = 'Incident ${data['incidentId']} has been updated';
      }

      if (title != null) {
        addNotification({
          'title': title,
          'message': message,
          'type': type,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void addNotification(Map<String, dynamic> notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}
