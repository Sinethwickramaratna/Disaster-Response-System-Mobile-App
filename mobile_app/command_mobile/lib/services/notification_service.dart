import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';
import 'assignment_service.dart';

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
    // Load historical notifications
    loadNotifications();

    _socketSub = SocketService.instance.onNotification.listen((data) {
      print('🔔 NotificationService: Received raw notification: $data');
      final id = data['id']?.toString() ?? data['notificationId']?.toString() ?? '';
      if (id.isNotEmpty && _processedIds.contains(id)) return;
      if (id.isNotEmpty) _processedIds.add(id);
      
      addNotification(data);
    });

    // Also listen for resource and assignment events to show as notifications
    _assignmentSub = SocketService.instance.onAssignmentUpdate.listen((data) {
      print('🛰️ NotificationService: Received assignment update: ${data['event']}');
      final type = data['type'] ?? 'Assignment';
      final event = data['event'] ?? '';
      
      String? title;
      String? message;
      String? dedupeId;

      if (data.containsKey('requestId')) {
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
        } else {
          message = 'Request ${data['requestId']} is now $status';
        }
      } else if (data.containsKey('incidentId')) {
        final status = data['status']?.toString().toUpperCase() ?? '';
        final updatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString() ?? '';
        dedupeId = 'inc:${data['incidentId']}:$event:$status:$updatedAt';
        
        if (dedupeId.isNotEmpty && _processedIds.contains(dedupeId)) return;
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
    super.dispose();
  }
}
