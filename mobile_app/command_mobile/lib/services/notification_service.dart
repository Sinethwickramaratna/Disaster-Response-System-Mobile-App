import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

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

  void _init() {
    _socketSub = SocketService.instance.onNotification.listen((data) {
      final id = data['id']?.toString() ?? data['notificationId']?.toString() ?? '';
      if (id.isNotEmpty && _processedIds.contains(id)) return;
      if (id.isNotEmpty) _processedIds.add(id);
      
      addNotification(data);
    });

    // Also listen for resource and assignment events to show as notifications
    _assignmentSub = SocketService.instance.onAssignmentUpdate.listen((data) {
      final type = data['type'] ?? 'Assignment';
      final event = data['event'] ?? '';
      
      String? title;
      String? message;
      String? dedupeId;

      if (data.containsKey('requestId')) {
        final status = data['status']?.toString().toUpperCase() ?? 'PENDING';
        dedupeId = 'res:${data['requestId']}:$event:$status';
        
        if (_processedIds.contains(dedupeId)) return;
        _processedIds.add(dedupeId);

        title = 'Resource Request';
        if (event == 'resourceRequest:deleted') {
          message = 'Request ${data['requestId']} was cancelled/removed';
        } else if (event == 'resourceRequest:created') {
          message = 'New request ${data['requestId']} submitted';
        } else {
          message = 'Request ${data['requestId']} is now $status';
        }
      } else if (data.containsKey('incidentId')) {
        final status = data['status']?.toString().toUpperCase() ?? '';
        dedupeId = 'inc:${data['incidentId']}:$event:$status';
        
        if (_processedIds.contains(dedupeId)) return;
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
    _processedIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _assignmentSub?.cancel();
    super.dispose();
  }
}
