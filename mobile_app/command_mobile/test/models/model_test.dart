import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/models/incident.dart';
import 'package:command_mobile/models/user.dart';

void main() {
  group('User model', () {
    test('stores required profile values', () {
      final user = User(serviceId: 'FO-A01', role: 'OFFICER', zone: 'ZONE-A');

      expect(user.serviceId, 'FO-A01');
      expect(user.role, 'OFFICER');
      expect(user.zone, 'ZONE-A');
    });
  });

  group('Incident model', () {
    test('stores required incident values and default media', () {
      final reportedAt = DateTime(2026, 5, 7, 9, 30);
      final incident = Incident(
        id: 'INC-1',
        type: 'Flooding',
        zone: 'ZONE-A',
        assignedTo: 'FO-A01',
        reportedAt: reportedAt,
        priority: 'HIGH',
        description: 'River overflow',
        latitude: 6.9271,
        longitude: 79.8612,
        status: IncidentStatus.reported,
      );

      expect(incident.id, 'INC-1');
      expect(incident.reportedAt, reportedAt);
      expect(incident.media, isEmpty);
      expect(incident.status, IncidentStatus.reported);
    });

    test('allows mutable status and description updates', () {
      final incident = Incident(
        id: 'INC-2',
        type: 'Road Block',
        zone: 'ZONE-B',
        assignedTo: '',
        reportedAt: DateTime(2026, 5, 7),
        priority: 'MEDIUM',
        description: 'Blocked road',
        latitude: 7.2906,
        longitude: 80.6337,
        status: IncidentStatus.assigned,
        media: const ['photo.jpg'],
      );

      incident.status = IncidentStatus.resolved;
      incident.description = 'Road cleared';

      expect(incident.status, IncidentStatus.resolved);
      expect(incident.description, 'Road cleared');
      expect(incident.media, ['photo.jpg']);
    });
  });
}
