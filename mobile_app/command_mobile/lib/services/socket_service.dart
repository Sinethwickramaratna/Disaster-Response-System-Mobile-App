import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'auth_service.dart';

class SocketService {
  SocketService._internal();

  static final SocketService instance = SocketService._internal();

  io.Socket? _socket;
  bool get connected => _socket?.connected ?? false;

  final StreamController<Map<String, dynamic>> _assignmentController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _alertController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _reportController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onAssignmentUpdate =>
      _assignmentController.stream;
  Stream<Map<String, dynamic>> get onAlert => _alertController.stream;
  Stream<Map<String, dynamic>> get onReportUpdate => _reportController.stream;
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  void pushNotification(Map<String, dynamic> payload) {
    _notificationController.add(payload);
  }

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    // Initialize socket on server if needed (Integrated server warm-up)
    try {
      final bridgeUrl = Uri.parse('${Env.apiBaseUrl}/api/socket');
      await http.get(
        bridgeUrl,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[SocketService] Bridge warm-up note: $e');
    }

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'token': token})
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .enableReconnection()
        .setReconnectionAttempts(5)
        .setReconnectionDelay(2000)
        .disableAutoConnect()
        .build();

    _socket = io.io(Env.apiSocketUrl, options);
    _bindEvents(_socket!);
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, dynamic payload) {
    _socket?.emit(event, payload);
  }

  void joinDistrict(String district) {
    final normalized = district.trim();
    if (normalized.isEmpty || _socket == null || !connected) return;
    _socket!.emit('join:district', normalized);
    debugPrint('[SocketService] join:district => $normalized');
  }

  void joinIncident(String incidentId) {
    final normalized = incidentId.trim();
    if (normalized.isEmpty || _socket == null || !connected) return;
    _socket!.emit('join:incident', normalized);
    debugPrint('[SocketService] join:incident => $normalized');
  }

  void _bindEvents(io.Socket socket) {
    socket.onConnect((_) {
      final district = AuthService.currentUser?.zone ?? '';
      debugPrint('[SocketService] connected to ${Env.apiSocketUrl}');
      if (district.trim().isNotEmpty) {
        joinDistrict(district);
      }
      debugPrint('[SocketService] frontend socket.io connected: ${socket.connected}');
    });

    socket.onReconnect((_) {
      final district = AuthService.currentUser?.zone ?? '';
      debugPrint('[SocketService] reconnected to ${Env.apiSocketUrl}');
      if (district.trim().isNotEmpty) {
        joinDistrict(district);
      }
    });

    socket.onConnectError((error) {
      debugPrint('[SocketService] connect error: $error');
    });

    socket.onDisconnect((reason) {
      debugPrint('[SocketService] disconnected: $reason');
      debugPrint('[SocketService] frontend socket.io connected: ${socket.connected}');
    });

    for (final eventName in const [
      'incident:assigned',
      'incident:updated',
      'assignment:update',
      'resource:assigned',
      'resource:statusUpdated',
      'resourceRequest:updated',
    ]) {
      socket.on(eventName, (data) => _assignmentController.add(_toMap(data)));
    }

    for (final eventName in const ['alert:critical', 'alert:public', 'alert:new']) {
      socket.on(eventName, (data) => _alertController.add(_toMap(data)));
    }

    for (final eventName in const ['report:assigned', 'report:update']) {
      socket.on(eventName, (data) => _reportController.add(_toMap(data)));
    }

    socket.on(
      'notification:new',
      (data) => _notificationController.add(_toMap(data)),
    );
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data == null) return <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'value': decoded};
    }
    return {'value': data};
  }

  void dispose() {
    disconnect();
    _assignmentController.close();
    _alertController.close();
    _reportController.close();
    _notificationController.close();
  }
}
