import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/models/incident.dart';
import 'package:command_mobile/services/incident_service.dart';

void main() {
  group('IncidentService', () {
    test('fetches all incidents when zone is null', () async {
      final incidents = await IncidentService.getIncidentsForZone(null);

      expect(incidents, isNotEmpty);
      expect(incidents.map((i) => i.id), containsAll(['INC-1001', 'INC-1002']));
    });

    test('fetches incidents for a selected zone', () async {
      final incidents = await IncidentService.getIncidentsForZone('ZONE-A');

      expect(incidents, isNotEmpty);
      expect(incidents.every((incident) => incident.zone == 'ZONE-A'), isTrue);
    });

    test('unknown zone returns an empty response', () async {
      final incidents = await IncidentService.getIncidentsForZone('UNKNOWN');

      expect(incidents, isEmpty);
    });

    test('updates incident status and emits update', () async {
      final update = IncidentService.updates.firstWhere((i) => i.id == 'INC-1001');

      await IncidentService.updateIncidentStatus(
        'INC-1001',
        IncidentStatus.verified,
      );

      final incident = await update;
      expect(incident.status, IncidentStatus.verified);
    });

    test('missing incident status update is ignored', () async {
      await IncidentService.updateIncidentStatus(
        'INC-NOT-FOUND',
        IncidentStatus.closed,
      );

      final incidents = await IncidentService.getIncidentsForZone(null);
      expect(incidents, isNotEmpty);
    });

    test('adds field observation to incident description', () async {
      const note = 'Water level rising near bridge';

      await IncidentService.addObservation('INC-1002', note);
      final incidents = await IncidentService.getIncidentsForZone('ZONE-B');
      final incident = incidents.firstWhere((i) => i.id == 'INC-1002');

      expect(incident.description, contains('[OBS] $note'));
    });

    test('resource request marks incident as needing resources', () async {
      await IncidentService.requestResources('INC-1002', ['Ambulance', 'Boat']);
      final incidents = await IncidentService.getIncidentsForZone('ZONE-B');
      final incident = incidents.firstWhere((i) => i.id == 'INC-1002');

      expect(incident.status, IncidentStatus.needResources);
      expect(incident.description, contains('[RESOURCES REQUESTED] Ambulance, Boat'));
    });
  });
}
