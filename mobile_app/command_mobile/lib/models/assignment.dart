dynamic _readValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key];
    }
  }
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

String _asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? fallback;
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().toLowerCase().trim();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

DateTime _asDateTime(dynamic value, [DateTime? fallback]) {
  if (value == null) return fallback ?? DateTime.now();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString()) ?? (fallback ?? DateTime.now());
}

class AssignmentSummary {
  final int criticalAlerts;
  final int activeIncidents;
  final int assignedResources;
  final int readinessScore;
  final SummaryBreakdown breakdown;

  AssignmentSummary({
    required this.criticalAlerts,
    required this.activeIncidents,
    required this.assignedResources,
    required this.readinessScore,
    required this.breakdown,
  });

  factory AssignmentSummary.fromJson(Map<String, dynamic> json) {
    return AssignmentSummary(
      criticalAlerts: _asInt(json['criticalAlerts']),
      activeIncidents: _asInt(json['activeIncidents']),
      assignedResources: _asInt(json['assignedResources']),
      readinessScore: _asInt(json['readinessScore']),
      breakdown: SummaryBreakdown.fromJson(json['breakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'criticalAlerts': criticalAlerts,
      'activeIncidents': activeIncidents,
      'assignedResources': assignedResources,
      'readinessScore': readinessScore,
      'breakdown': breakdown.toJson(),
    };
  }
}

class SummaryBreakdown {
  final double assignmentRatio;
  final double resourceRatio;
  final int activeAssignments;
  final int totalAssignments;
  final int readyResources;
  final int totalResources;

  SummaryBreakdown({
    required this.assignmentRatio,
    required this.resourceRatio,
    required this.activeAssignments,
    required this.totalAssignments,
    required this.readyResources,
    required this.totalResources,
  });

  factory SummaryBreakdown.fromJson(Map<String, dynamic> json) {
    return SummaryBreakdown(
      assignmentRatio: _asDouble(json['assignmentRatio']),
      resourceRatio: _asDouble(json['resourceRatio']),
      activeAssignments: _asInt(json['activeAssignments']),
      totalAssignments: _asInt(json['totalAssignments']),
      readyResources: _asInt(json['readyResources']),
      totalResources: _asInt(json['totalResources']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentRatio': assignmentRatio,
      'resourceRatio': resourceRatio,
      'activeAssignments': activeAssignments,
      'totalAssignments': totalAssignments,
      'readyResources': readyResources,
      'totalResources': totalResources,
    };
  }
}

class AssignmentIncident {
  final String assignmentId;
  final String? incidentId;
  final String role;
  final String status;
  final DateTime assignedAt;
  final IncidentData? incident;

  AssignmentIncident({
    required this.assignmentId,
    this.incidentId,
    required this.role,
    required this.status,
    required this.assignedAt,
    this.incident,
  });

  factory AssignmentIncident.fromJson(Map<String, dynamic> json) {
    final incidentJson = _asMap(json['incident']) ?? json;
    return AssignmentIncident(
      assignmentId: _asString(_readValue(json, ['assignmentId', 'assignment_id', 'id']), 'unknown-assignment'),
      incidentId: _asString(_readValue(json, ['incidentId', 'incident_id']), _asString(_readValue(incidentJson, ['incidentId', 'incident_id', 'id']),'') ),
      role: _asString(_readValue(json, ['assignedRole', 'assigned_role', 'role']), 'UNKNOWN'),
      status: _asString(_readValue(json, ['assignmentStatus', 'status']), 'ACTIVE'),
      assignedAt: _asDateTime(_readValue(json, ['assignedAt', 'assigned_at', 'createdAt', 'created_at'])),
      incident: IncidentData.fromJson(incidentJson),
    );
  }
}

class IncidentData {
  final String? incidentId;
  final String title;
  final String severity;
  final int? affectedPopulation;
  final String status;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? closedAt;
  final DivisionData? division;
  final String? description;
  final bool publicVisibility;

  IncidentData({
    this.incidentId,
    required this.title,
    required this.severity,
    this.affectedPopulation,
    required this.status,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.closedAt,
    this.division,
    this.description,
    this.publicVisibility = true,
  });

  factory IncidentData.fromJson(Map<String, dynamic> json) {
    final divisionJson = _asMap(json['division']) ?? _asMap(json['Division']);
    return IncidentData(
      incidentId: _asString(_readValue(json, ['incidentId', 'incident_id', 'id']), ''),
      title: _asString(_readValue(json, ['title', 'name']), 'Unknown Incident'),
      severity: _asString(_readValue(json, ['severity']), 'LOW'),
      affectedPopulation: _asInt(_readValue(json, ['affected_population', 'affectedPeople', 'affectedPopulation'])),
      status: _asString(_readValue(json, ['status']), 'ACTIVE'),
      latitude: _readValue(json, ['latitude']) != null
          ? _asDouble(_readValue(json, ['latitude']))
          : _asMap(json['location'])?['latitude'] != null
              ? _asDouble(_asMap(json['location'])?['latitude'])
              : null,
      longitude: _readValue(json, ['longitude']) != null
          ? _asDouble(_readValue(json, ['longitude']))
          : _asMap(json['location'])?['longitude'] != null
              ? _asDouble(_asMap(json['location'])?['longitude'])
              : null,
      createdAt: _asDateTime(_readValue(json, ['created_at', 'createdAt'])),
      closedAt: _readValue(json, ['closed_at', 'closedAt']) != null
          ? _asDateTime(_readValue(json, ['closed_at', 'closedAt']))
          : null,
      division: divisionJson != null ? DivisionData.fromJson(divisionJson) : null,
      description: _readValue(json, ['description'])?.toString(),
      publicVisibility: _asBool(_readValue(json, ['publicVisibility', 'public_visibility']), true),
    );
  }
}

class DivisionData {
  final int? divisionId;
  final String divisionName;
  final String? district;
  final String? province;

  DivisionData({
    this.divisionId,
    required this.divisionName,
    this.district,
    this.province,
  });

  factory DivisionData.fromJson(Map<String, dynamic> json) {
    return DivisionData(
      divisionId: _asInt(_readValue(json, ['division_id', 'divisionId'])),
      divisionName: _asString(_readValue(json, ['division_name', 'divisionName']), 'Unknown Division'),
      district: _readValue(json, ['district'])?.toString(),
      province: _readValue(json, ['province'])?.toString(),
    );
  }
}

class AlertData {
  final String id;
  final String scope;
  final String type;
  final String severity;
  final String title;
  final String? description;
  final String district;
  final bool isPublic;
  final bool isActive;
  final String? source;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? incidentId;

  AlertData({
    required this.id,
    required this.scope,
    required this.type,
    required this.severity,
    required this.title,
    this.description,
    required this.district,
    required this.isPublic,
    required this.isActive,
    this.source,
    required this.createdAt,
    this.expiresAt,
    this.incidentId,
  });

  factory AlertData.fromJson(Map<String, dynamic> json) {
    final scope = _asString(_readValue(json, ['scope']), 'all').toLowerCase();
    final isPublic = _asBool(_readValue(json, ['isPublic', 'is_public']), scope == 'citizen');
    return AlertData(
      id: _asString(_readValue(json, ['id']), 'unknown-alert'),
      scope: scope,
      type: _asString(_readValue(json, ['type', 'alertType', 'alert_type']), 'UNKNOWN'),
      severity: _asString(_readValue(json, ['severity']), 'LOW'),
      title: _asString(_readValue(json, ['title']), 'Untitled Alert'),
      description: _readValue(json, ['description'])?.toString(),
      district: _asString(_readValue(json, ['district']), ''),
      isPublic: isPublic,
      isActive: _asBool(_readValue(json, ['isActive', 'is_active']), _asString(_readValue(json, ['status']), 'ACTIVE').toUpperCase() != 'RESOLVED'),
      source: _readValue(json, ['source'])?.toString(),
      createdAt: _asDateTime(_readValue(json, ['createdAt', 'created_at'])),
      expiresAt: _readValue(json, ['expiresAt', 'expires_at']) != null
          ? _asDateTime(_readValue(json, ['expiresAt', 'expires_at']))
          : null,
      incidentId: _readValue(json, ['incidentId', 'incident_id'])?.toString(),
    );
  }
}

class ResourceDeployment {
  final String deploymentId;
  final String status;
  final dynamic itemsDispatched;
  final DateTime dispatchedAt;
  final DateTime? completedAt;
  final String? deliveryNotes;
  final String? incidentId;

  ResourceDeployment({
    required this.deploymentId,
    required this.status,
    this.itemsDispatched,
    required this.dispatchedAt,
    this.completedAt,
    this.deliveryNotes,
    this.incidentId,
  });

  factory ResourceDeployment.fromJson(Map<String, dynamic> json) {
    final items = _readValue(json, ['items', 'items_dispatched', 'itemsDispatched']);
    return ResourceDeployment(
      deploymentId: _asString(_readValue(json, ['deployment_id', 'deploymentId']), 'unknown-deployment'),
      status: _asString(_readValue(json, ['status']), 'PENDING'),
      itemsDispatched: items,
      dispatchedAt: _asDateTime(_readValue(json, ['dispatched_at', 'dispatchedAt'])),
      completedAt: _readValue(json, ['completed_at', 'completedAt']) != null
          ? _asDateTime(_readValue(json, ['completed_at', 'completedAt']))
          : null,
      deliveryNotes: _readValue(json, ['delivery_notes', 'deliveryNotes'])?.toString(),
      incidentId: _readValue(json, ['incident_id', 'incidentId'])?.toString(),
    );
  }
}

class ResourceRequestData {
  final String requestId;
  final String incidentId;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final List<ResourceRequestItem> items;

  ResourceRequestData({
    required this.requestId,
    required this.incidentId,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    required this.items,
  });

  factory ResourceRequestData.fromJson(Map<String, dynamic> json) {
    final rawItems = _readValue(json, ['items']);
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(ResourceRequestItem.fromJson)
            .toList(growable: false)
        : const <ResourceRequestItem>[];

    return ResourceRequestData(
      requestId: _asString(_readValue(json, ['requestId', 'request_id']), 'unknown-request'),
      incidentId: _asString(_readValue(json, ['incidentId', 'incident_id']), 'unknown-incident'),
      status: _asString(_readValue(json, ['status']), 'PENDING'),
      createdAt: _asDateTime(_readValue(json, ['createdAt', 'created_at'])),
      reviewedAt: _readValue(json, ['reviewedAt', 'reviewed_at']) != null
          ? _asDateTime(_readValue(json, ['reviewedAt', 'reviewed_at']))
          : null,
      items: items,
    );
  }
}

class ResourceRequestItem {
  final String resourceType;
  final int quantity;
  final String priority;

  const ResourceRequestItem({
    required this.resourceType,
    required this.quantity,
    required this.priority,
  });

  factory ResourceRequestItem.fromJson(Map<String, dynamic> json) {
    return ResourceRequestItem(
      resourceType: _asString(_readValue(json, ['resourceType', 'resource_type']), 'UNKNOWN'),
      quantity: _asInt(_readValue(json, ['quantity']), 0),
      priority: _asString(_readValue(json, ['priority']), 'MEDIUM'),
    );
  }
}

class ShelterData {
  final int shelterId;
  final String name;
  final int capacity;
  final int occupancy;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? contactPerson;
  final String? contactPhone;

  ShelterData({
    required this.shelterId,
    required this.name,
    required this.capacity,
    required this.occupancy,
    this.distanceKm,
    this.latitude,
    this.longitude,
    required this.status,
    this.contactPerson,
    this.contactPhone,
  });

  factory ShelterData.fromJson(Map<String, dynamic> json) {
    return ShelterData(
      shelterId: _asInt(_readValue(json, ['shelterId', 'shelter_id'])),
      name: _asString(_readValue(json, ['name']), 'Unknown Shelter'),
      capacity: _asInt(_readValue(json, ['capacity', 'max_capacity'])),
      occupancy: _asInt(_readValue(json, ['occupancy', 'current_occupancy'])),
      distanceKm: _readValue(json, ['distanceKm', 'distance_km']) != null
          ? _asDouble(_readValue(json, ['distanceKm', 'distance_km']))
          : null,
      latitude: _readValue(json, ['latitude']) != null
          ? _asDouble(_readValue(json, ['latitude']))
          : _asMap(json['location'])?['latitude'] != null
              ? _asDouble(_asMap(json['location'])?['latitude'])
              : null,
      longitude: _readValue(json, ['longitude']) != null
          ? _asDouble(_readValue(json, ['longitude']))
          : _asMap(json['location'])?['longitude'] != null
              ? _asDouble(_asMap(json['location'])?['longitude'])
              : null,
      status: _asString(_readValue(json, ['status']), 'UNKNOWN'),
      contactPerson: _readValue(json, ['contactPerson', 'contact_person'])?.toString(),
      contactPhone: _readValue(json, ['contactPhone', 'contact_phone'])?.toString(),
    );
  }
}

class ReportData {
  final String reportId;
  final String incidentId;
  final String title;
  final String disasterType;
  final String severity;
  final String status;
  final String assignedRole;
  final String? description;
  final String district;
  final int affectedPeople;
  final LocationData location;
  final DateTime reportedAt;
  final DateTime updatedAt;
  final DateTime assignedAt;
  final String source;
  final String? contact;
  final List<String> mediaUrls;
  final String verificationStatus;
  final String? sosId;
  final String? deviceId;
  final String? officerNotes;
  final String? reviewedById;
  final DateTime? reviewedAt;

  ReportData({
    required this.reportId,
    required this.incidentId,
    required this.title,
    required this.disasterType,
    required this.severity,
    required this.status,
    required this.assignedRole,
    this.description,
    required this.district,
    required this.affectedPeople,
    required this.location,
    required this.reportedAt,
    required this.updatedAt,
    required this.assignedAt,
    required this.source,
    this.contact,
    required this.mediaUrls,
    required this.verificationStatus,
    this.sosId,
    this.deviceId,
    this.officerNotes,
    this.reviewedById,
    this.reviewedAt,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final locationJson = _asMap(_readValue(json, ['location']));
    final disasterType = _asString(_readValue(json, ['disasterType', 'disaster_type']), 'UNKNOWN');
    final verificationStatus = _asString(
      _readValue(json, ['verificationStatus', 'verification_status', 'status']),
      'PENDING',
    );
    final source = _asString(_readValue(json, ['source', 'report_source']), 'UNKNOWN');
    final mediaRaw = _readValue(json, ['mediaUrls', 'media_urls']);
    final mediaUrls = mediaRaw is List
        ? mediaRaw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList(growable: false)
        : const <String>[];
    final incidentId = _asString(_readValue(json, ['incidentId', 'incident_id']), 'unknown-incident');
    final reportId = _asString(_readValue(json, ['reportId', 'report_id', 'id']), 'unknown-report');

    return ReportData(
      reportId: reportId,
      incidentId: incidentId,
      title: _asString(
        _readValue(json, ['title']),
        '$disasterType Report',
      ),
      disasterType: disasterType,
      severity: _asString(_readValue(json, ['severity']), 'LOW'),
      status: verificationStatus,
      assignedRole: _asString(_readValue(json, ['assignedRole', 'assigned_role', 'assignedTo']), 'UNKNOWN'),
      description: _readValue(json, ['description'])?.toString(),
      district: _asString(_readValue(json, ['district']), 'UNKNOWN'),
      affectedPeople: _asInt(_readValue(json, ['affectedPeople', 'affected_people'])),
      location: LocationData.fromJson(
        locationJson ?? {
          'latitude': _readValue(json, ['latitude']),
          'longitude': _readValue(json, ['longitude']),
        },
      ),
      reportedAt: _asDateTime(_readValue(json, ['reportedAt', 'reported_at', 'createdAt', 'created_at'])),
      updatedAt: _asDateTime(_readValue(json, ['updatedAt', 'updated_at'])),
      assignedAt: _asDateTime(_readValue(json, ['assignedAt', 'assigned_at', 'createdAt', 'created_at'])),
      source: source,
      contact: _readValue(json, ['contact'])?.toString(),
      mediaUrls: mediaUrls,
      verificationStatus: verificationStatus,
      sosId: _readValue(json, ['sosId', 'sos_id'])?.toString(),
      deviceId: _readValue(json, ['deviceId', 'device_id'])?.toString(),
      officerNotes: _readValue(json, ['officerNotes', 'officer_notes'])?.toString(),
      reviewedById: _readValue(json, ['reviewedById', 'reviewed_by_id'])?.toString(),
      reviewedAt: _readValue(json, ['reviewedAt', 'reviewed_at']) != null
          ? _asDateTime(_readValue(json, ['reviewedAt', 'reviewed_at']))
          : null,
    );
  }
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }
}
