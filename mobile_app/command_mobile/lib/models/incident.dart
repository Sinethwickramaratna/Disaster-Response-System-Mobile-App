
enum IncidentStatus {
  reported,
  assigned,
  onTheWay,
  reached,
  verified,
  inProgress,
  needResources,
  resolved,
  closed,
}

class Incident {
  final String id;
  final String type;
  final String zone;
  final String assignedTo; // serviceId or empty
  final DateTime reportedAt;
  final String priority;
  String description;
  final double latitude;
  final double longitude;
  IncidentStatus status;
  final List<String> media;

  Incident({
    required this.id,
    required this.type,
    required this.zone,
    required this.assignedTo,
    required this.reportedAt,
    required this.priority,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.media = const [],
  });
}
