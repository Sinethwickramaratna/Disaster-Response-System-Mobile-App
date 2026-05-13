library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/assignment.dart';
import 'auth_service.dart';

class AssignmentService {
  static const _timeout = Duration(seconds: 60);
  static const _cacheTtl = Duration(seconds: 15);

  static final Map<String, _CacheEntry<dynamic>> _cache = {};
  static final Map<String, Future<dynamic>> _inFlight = {};

  // District to Zone ID mapping for Sri Lanka
  static const Map<String, int> districtZoneMap = {
    'Colombo': 1,
    'Gampaha': 2,
    'Kalutara': 3,
    'Kandy': 4,
    'Matara': 5,
    'Galle': 6,
    'Hambantota': 7,
    'Jaffna': 8,
    'Mullaitivu': 9,
    'Batticaloa': 10,
    'Ampara': 11,
    'Trincomalee': 12,
    'Kurunegala': 13,
    'Puttalam': 14,
    'Anuradhapura': 15,
    'Polonnaruwa': 16,
    'Badulla': 17,
    'Monaragala': 18,
    'Ratnapura': 19,
    'Kegalle': 20,
  };

  static int? getZoneIdByDistrict(String? districtName) {
    if (districtName == null || districtName.isEmpty) return null;
    return districtZoneMap[districtName];
  }

  static Future<AssignmentSummary?> fetchSummary() async {
    final decoded = await _cachedJson('/api/assignments/summary');
    if (decoded is Map<String, dynamic>) {
      return AssignmentSummary.fromJson(decoded);
    }
    throw const FormatException('Invalid summary response');
  }

  static Future<List<AssignmentIncident>> fetchIncidents({
    String? status,
    String? severity,
    bool ignoreCache = false,
  }) async {
    final query = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (severity != null && severity.trim().isNotEmpty) {
      query['severity'] = severity.trim();
    }

    final decoded = await _cachedJson(
      '/api/assignments/incidents',
      queryParameters: query,
      ignoreCache: ignoreCache,
    );

    return _asList(decoded)
        .map(AssignmentIncident.fromJson)
        .toList(growable: false);
  }

  static Future<List<AlertData>> fetchAlerts({String scope = 'all'}) async {
    final decoded = await _cachedJson(
      '/api/assignments/alerts',
      queryParameters: {'scope': scope},
    );

    return _asList(decoded).map(AlertData.fromJson).toList(growable: false);
  }

  static Future<ResourcesResponse?> fetchResources({bool ignoreCache = false}) async {
    final decoded = await _cachedJson('/api/resources/assigned', ignoreCache: ignoreCache);
    final resources = _asList(decoded)
        .map(ResourceDeployment.fromJson)
        .toList(growable: false);

    return _buildResourcesResponse(resources);
  }

  static Future<List<ResourceRequestData>> fetchMyResourceRequests({bool ignoreCache = false}) async {
    final decoded = await _cachedJson('/api/resources/requests/mine', ignoreCache: ignoreCache);
    return _asList(decoded)
        .map(ResourceRequestData.fromJson)
        .toList(growable: false);
  }

  static Future<List<ShelterData>> fetchNearbyShelters({int? zoneId, String? district}) async {
    print('🔍 DEBUG: Fetching nearby shelters for zoneId=$zoneId district=$district');
    print('🔍 DEBUG: API Base URL: ${Env.apiBaseUrl}');
    print('🔍 DEBUG: Full endpoint: ${Env.apiBaseUrl}/api/shelters/near');
    
    try {
      final queryParameters = <String, String>{};
      final assignedArea = district?.trim();
      final assignedDivisionId = assignedArea == null || assignedArea.isEmpty
          ? null
          : int.tryParse(assignedArea);

      if (zoneId != null) {
        queryParameters['zoneId'] = zoneId.toString();
      } else if (assignedDivisionId != null && assignedDivisionId > 0) {
        queryParameters['zoneId'] = assignedDivisionId.toString();
      } else if (assignedArea != null && assignedArea.isNotEmpty) {
        queryParameters['district'] = assignedArea;
      }

      final decoded = await _cachedJson(
        '/api/shelters/near',
        queryParameters: queryParameters,
      );
      print('✅ DEBUG: Shelters response received: $decoded');
      
      final shelters = _asList(decoded).map(ShelterData.fromJson).toList(growable: false);
      print('✅ DEBUG: Parsed ${shelters.length} shelters');
      return shelters;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error fetching shelters: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<ReportsResponse?> fetchReports() async {
    final decoded = await _cachedJson('/api/reports/assigned');
    final reports = _asList(decoded).map(ReportData.fromJson).toList(growable: false);

    return _buildReportsResponse(reports);
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final decoded = await _cachedJson('/api/notifications');
    return _asList(decoded);
  }

  static Future<ReportData?> fetchReportById(String reportId) async {
    final cleanId = reportId.trim();
    if (cleanId.isEmpty) return null;

    final decoded = await _cachedJson('/api/reports/$cleanId');
    if (decoded is Map<String, dynamic>) {
      return ReportData.fromJson(decoded);
    }
    return null;
  }

  static Future<bool> submitResourceRequest({
    required String incidentId,
    required String resourceType,
    required int quantity,
    required String priority,
    String? notes,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/api/resources/requests',
      body: {
        'incidentId': incidentId,
        'resourceType': resourceType,
        'quantity': quantity,
        'priority': priority,
        'notes': notes,
      },
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<bool> updateIncident({
    required String incidentId,
    String? description,
    int? affectedPeople,
    String? status,
    String? severity,
  }) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/api/incidents/$incidentId',
      body: {
        if (description != null) 'description': description,
        if (affectedPeople != null) 'affectedPeople': affectedPeople,
        if (status != null) 'status': status,
        if (severity != null) 'severity': severity,
      },
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<bool> updateDeployment({
    required String deploymentId,
    required String status,
    String? deliveryNotes,
  }) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/api/resources/deployments/$deploymentId',
      body: {
        'status': status,
        if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
      },
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> fetchResourceRequestDetails(String requestId) async {
    final decoded = await _cachedJson('/api/resources/requests/$requestId');
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  static Future<dynamic> _authorizedJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    print('📡 DEBUG: Making authorized JSON request');
    print('   Path: $path');
    print('   Query params: $queryParameters');
    
    try {
      final response = await _authorizedRequest(
        'GET',
        path,
        queryParameters: queryParameters,
      );

      print('📡 DEBUG: Response received - Status: ${response.statusCode}');
      print('   URL: ${response.request?.url}');
      print('   Headers: ${response.request?.headers}');
      print('   Body length: ${response.body.length}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMsg = _errorMessage(response);
        print('❌ DEBUG: HTTP Error - $errorMsg');
        throw HttpException(errorMsg, uri: response.request?.url);
      }

      final result = response.body.trim().isEmpty ? null : jsonDecode(response.body);
      print('✅ DEBUG: Parsed response: $result');
      return result;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Request failed: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<dynamic> _cachedJson(
    String path, {
    Map<String, String>? queryParameters,
    bool ignoreCache = false,
  }) async {
    final cacheKey = _cacheKey(path, queryParameters);
    
    if (ignoreCache) {
      _cache.remove(cacheKey);
      _inFlight.remove(cacheKey);
    }

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null && !ignoreCache) {
      return inFlight;
    }

    final future = _authorizedJson(path, queryParameters: queryParameters).then((value) {
      _cache[cacheKey] = _CacheEntry(value, DateTime.now().add(_cacheTtl));
      return value;
    }).whenComplete(() {
      _inFlight.remove(cacheKey);
    });

    _inFlight[cacheKey] = future;
    return future;
  }

  static String _cacheKey(String path, Map<String, String>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return path;
    }

    final sortedEntries = queryParameters.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final encodedQuery = sortedEntries.map((entry) => '${entry.key}=${entry.value}').join('&');
    return '$path?$encodedQuery';
  }

  static Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      print('❌ DEBUG: No authentication token available!');
      throw const HttpException('Missing authentication token');
    }

    final uri = Uri.parse('${Env.apiBaseUrl}$path').replace(
      queryParameters:
          queryParameters == null || queryParameters.isEmpty ? null : queryParameters,
    );

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final requestBody = body == null ? null : jsonEncode(body);

    print('🌐 DEBUG: Building $method request');
    print('   API Base: ${Env.apiBaseUrl}');
    print('   Path: $path');
    print('   Full URL: $uri');
    print('   Content-Type: ${headers['Content-Type']}');
    print('   Authorization: Bearer ${token.substring(0, 10)}...${token.length} chars total');
    print('   Request has body: ${requestBody != null}');

    try {
      final response = switch (method) {
        'POST' => await http.post(uri, headers: headers, body: requestBody).timeout(_timeout),
        'PATCH' => await http.patch(uri, headers: headers, body: requestBody).timeout(_timeout),
        'PUT' => await http.put(uri, headers: headers, body: requestBody).timeout(_timeout),
        'DELETE' => await http.delete(uri, headers: headers).timeout(_timeout),
        _ => await http.get(uri, headers: headers).timeout(_timeout),
      };
      print('✅ DEBUG: HTTP $method completed with status ${response.statusCode}');
      print('   Response headers: ${response.headers}');
      print('   Response body (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      return response;
    } catch (e, stackTrace) {
      print('❌ DEBUG: HTTP $method failed: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _asList(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'] ?? decoded['items'] ?? decoded['results'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }

    return const [];
  }

  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Request failed (${response.statusCode})';
      }
    } catch (_) {}

    return 'Request failed (${response.statusCode})';
  }

  static ResourcesResponse _buildResourcesResponse(
    List<ResourceDeployment> resources,
  ) {
    return ResourcesResponse(
      total: resources.length,
      ready: resources
          .where((resource) => resource.status.toUpperCase() == 'READY')
          .length,
      deployed: resources
          .where((resource) => resource.status.toUpperCase() == 'DEPLOYED')
          .length,
      delivered: resources
          .where((resource) => resource.status.toUpperCase() == 'DELIVERED')
          .length,
      pending: resources
          .where((resource) => resource.status.toUpperCase() == 'PENDING')
          .length,
      resources: resources,
    );
  }

  static ReportsResponse _buildReportsResponse(List<ReportData> reports) {
    final activeCount = reports.where((report) {
      final status = report.status.toUpperCase();
      return status == 'PENDING' || status == 'IN_PROGRESS' || status == 'ACTIVE' || status == 'UNDER_REVIEW';
    }).length;

    final completedCount = reports.where((report) {
      final status = report.status.toUpperCase();
      return status == 'COMPLETED' || status == 'RESOLVED' || status == 'CLOSED' || status == 'VERIFIED' || status == 'REJECTED';
    }).length;

    return ReportsResponse(
      count: reports.length,
      reports: reports,
      activeCount: activeCount,
      completedCount: completedCount,
      pendingCount: reports
          .where((report) => report.status.toUpperCase() == 'PENDING' || report.status.toUpperCase() == 'UNDER_REVIEW')
          .length,
    );
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ResourcesResponse {
  final int total;
  final int ready;
  final int deployed;
  final int delivered;
  final int pending;
  final List<ResourceDeployment> resources;

  ResourcesResponse({
    required this.total,
    required this.ready,
    required this.deployed,
    required this.delivered,
    required this.pending,
    required this.resources,
  });
}

class ReportsResponse {
  final int count;
  final List<ReportData> reports;
  final int activeCount;
  final int completedCount;
  final int pendingCount;

  ReportsResponse({
    required this.count,
    required this.reports,
    required this.activeCount,
    required this.completedCount,
    required this.pendingCount,
  });
}
