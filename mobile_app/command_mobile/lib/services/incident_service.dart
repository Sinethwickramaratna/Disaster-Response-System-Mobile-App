import 'dart:async';

import 'assignment_service.dart';
import '../models/assignment.dart';
import '../models/incident.dart';

/// Incident service used by the mobile app.
/// Uses the authenticated assignment API as the source of truth.
class IncidentService {
  static List<Incident> _incidents = [];

  static final StreamController<Incident> _updates = StreamController.broadcast();

  /// Stream of incident updates for UI to listen and sync with dashboard.
  static Stream<Incident> get updates => _updates.stream;

  /// Returns incidents for a specific zone. If zone is null, returns all.
  static Future<List<Incident>> getIncidentsForZone(String? zone) async {
    final source = await _fetchRemoteIncidents();
    _incidents = source;

    if (zone == null || zone.trim().isEmpty) {
      return List.from(source);
    }

    final normalizedZone = zone.trim().toUpperCase();
    final filtered = source
        .where((incident) => incident.zone.toUpperCase() == normalizedZone)
        .toList();

    return filtered;
  }

  /// Update incident status and broadcast change.
  static Future<void> updateIncidentStatus(String incidentId, IncidentStatus status) async {
    final idx = _incidents.indexWhere((i) => i.id == incidentId);
    if (idx == -1) return;

    final String dbStatus = switch (status) {
      IncidentStatus.onTheWay => 'EN_ROUTE',
      IncidentStatus.reached => 'ON_SITE',
      IncidentStatus.verified => 'ACTIVE',
      IncidentStatus.resolved => 'RESOLVED',
      IncidentStatus.closed => 'CLOSED',
      _ => 'ACTIVE',
    };

    // Call the API
    await AssignmentService.updateIncident(
      incidentId: incidentId,
      status: dbStatus,
    );

    _incidents[idx].status = status;
    _updates.add(_incidents[idx]);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Add a field observation (appends to description for now) and broadcast.
  static Future<void> addObservation(String incidentId, String note) async {
    final idx = _incidents.indexWhere((i) => i.id == incidentId);
    if (idx == -1) return;
    final cur = _incidents[idx];
    cur.description = '${cur.description}\n\n[OBS] $note';
    _updates.add(cur);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Resource request currently attaches 'needResources' status and broadcasts.
  static Future<void> requestResources(String incidentId, List<String> resources) async {
    if (resources.isEmpty) {
      return;
    }

    final resourceType = resources.first;
    final quantity = resources.length;
    final notes = resources.join(', ');

    await AssignmentService.submitResourceRequest(
      incidentId: incidentId,
      resourceType: resourceType,
      quantity: quantity,
      priority: 'HIGH',
      notes: notes,
    );

    final idx = _incidents.indexWhere((i) => i.id == incidentId);
    if (idx == -1) return;
    _incidents[idx].status = IncidentStatus.needResources;
    _incidents[idx].description = '${_incidents[idx].description}\n\n[RESOURCES REQUESTED] ${resources.join(', ')}';
    _updates.add(_incidents[idx]);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static Future<List<Incident>> _fetchRemoteIncidents() async {
    final assignments = await AssignmentService.fetchIncidents();
    return assignments.map(_incidentFromAssignment).toList();
  }

  static Incident _incidentFromAssignment(AssignmentIncident assignment) {
    final incident = assignment.incident;
    final resolvedZone = incident?.division?.district ?? incident?.division?.divisionName ?? assignment.role;
    final resolvedPriority = _priorityFromSeverity(incident?.severity?.name ?? assignment.status);

    return Incident(
      id: assignment.assignmentId.isNotEmpty
          ? assignment.assignmentId
          : (incident?.incidentId?.toString() ?? 'INC-UNKNOWN'),
      type: incident?.title ?? 'Assigned Incident',
      zone: resolvedZone.isNotEmpty ? resolvedZone : 'UNKNOWN',
      assignedTo: assignment.role,
      reportedAt: assignment.assignedAt,
      priority: resolvedPriority,
      description: _incidentDescription(assignment),
      latitude: incident?.latitude ?? 0,
      longitude: incident?.longitude ?? 0,
      status: _statusFromAssignment(assignment.status),
      media: const [],
    );
  }

  static String _incidentDescription(AssignmentIncident assignment) {
    final incident = assignment.incident;
    final parts = <String>[
      'Title: ${incident?.title ?? 'Assigned Incident'}',
      if (incident?.severity != null) 'Severity: ${incident!.severity.name}',
      if (incident?.division?.district != null) 'District: ${incident!.division!.district}',
      if (incident?.division?.province != null) 'Province: ${incident!.division!.province}',
      'Assignment status: ${assignment.status}',
    ];
    return parts.join(' · ');
  }

  static String _priorityFromSeverity(String severity) {
    final normalized = severity.trim().toUpperCase();
    if (normalized == 'CRITICAL' || normalized == 'HIGH') {
      return 'HIGH';
    }
    if (normalized == 'MEDIUM') {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  static IncidentStatus _statusFromAssignment(String status) {
    switch (status.trim().toUpperCase()) {
      case 'ACTIVE':
        return IncidentStatus.assigned;
      case 'UNDER_RESPONSE':
        return IncidentStatus.inProgress;
      case 'RESOLVED':
        return IncidentStatus.resolved;
      case 'CLOSED':
        return IncidentStatus.closed;
      default:
        return IncidentStatus.reported;
    }
  }
}
