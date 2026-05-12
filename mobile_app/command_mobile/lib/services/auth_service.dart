library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/user.dart';

class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 20);

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _nameKey = 'user_name';
  static const _roleKey = 'user_role';
  static const _serviceIdKey = 'user_service_id';
  static const _zoneKey = 'user_zone';

  static User? currentUser;
  static String? _lastErrorMessage;

  static String? get lastErrorMessage => _lastErrorMessage;

  static Future<User?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    _lastErrorMessage = null;

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return _fail('Enter a valid email address');
    }

    if (cleanPassword.isEmpty) {
      return _fail('Enter your password');
    }

    final uri = Uri.parse('${Env.apiBaseUrl}/api/auth/login');

    try {
      debugPrint('[AuthService] POST $uri');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'password': cleanPassword,
            }),
          )
          .timeout(_timeout);

      final body = _decodeObject(response.body);

      if (response.statusCode == 200) {
        final token = body['token']?.toString();
        final userBody = body['user'] is Map<String, dynamic>
            ? body['user'] as Map<String, dynamic>
            : <String, dynamic>{};

        if (token == null || token.isEmpty) {
          return _fail('Login response did not include a token');
        }

        final user = _userFromLogin(userBody, cleanEmail);
        currentUser = user;
        await _persistSession(user, token);
        return user;
      }

      if (response.statusCode == 401) {
        return _fail('Invalid email or password');
      }

      if (response.statusCode == 403) {
        return _fail('This account is not allowed to use the mobile app');
      }

      return _fail(
        body['message']?.toString() ??
            body['error']?.toString() ??
            'Login failed (${response.statusCode})',
      );
    } on TimeoutException {
      return _fail('Backend request timed out at ${uri.origin}');
    } on SocketException {
      return _fail('Unable to reach backend at ${uri.origin}');
    } on FormatException {
      return _fail('Backend returned invalid JSON');
    } catch (error) {
      debugPrint('[AuthService] Login failed: $error');
      return _fail('Unable to login. Please try again.');
    }
  }

  static Future<void> initializeSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      currentUser = null;
      return;
    }

    currentUser = User(
      serviceId: await _storage.read(key: _serviceIdKey) ?? '',
      role: await _storage.read(key: _roleKey) ?? 'FIELD_OFFICER',
      zone: await _storage.read(key: _zoneKey) ?? 'UNKNOWN',
      userId: await _storage.read(key: _userIdKey),
      email: await _storage.read(key: _emailKey),
      name: await _storage.read(key: _nameKey),
    );
  }

  static Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> signOut() async {
    currentUser = null;
    _lastErrorMessage = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _serviceIdKey);
    await _storage.delete(key: _zoneKey);
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static User _userFromLogin(Map<String, dynamic> json, String fallbackEmail) {
    final userId = json['userId']?.toString();
    final email = json['email']?.toString() ?? fallbackEmail;
    final zone =
        json['assignedDistrict']?.toString() ??
        json['zone']?.toString() ??
        'UNKNOWN';

    return User(
      serviceId: userId ?? email.split('@').first,
      role: json['role']?.toString() ?? 'FIELD_OFFICER',
      zone: zone,
      userId: userId,
      email: email,
      name: json['name']?.toString(),
    );
  }

  static Future<void> _persistSession(User user, String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: user.userId ?? '');
    await _storage.write(key: _serviceIdKey, value: user.serviceId);
    await _storage.write(key: _emailKey, value: user.email ?? '');
    await _storage.write(key: _nameKey, value: user.name ?? '');
    await _storage.write(key: _roleKey, value: user.role);
    await _storage.write(key: _zoneKey, value: user.zone);
  }

  static User? _fail(String message) {
    currentUser = null;
    _lastErrorMessage = message;
    debugPrint('[AuthService] $message');
    return null;
  }
}
