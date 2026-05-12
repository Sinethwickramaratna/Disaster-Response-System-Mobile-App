import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/components/nav_bar.dart';
import 'package:command_mobile/models/incident.dart';
import 'package:command_mobile/screens/dashboard_screen.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/services/auth_service.dart';
import 'package:command_mobile/services/incident_service.dart';

import '../test_helpers.dart';

const _incidentLoadDelay = Duration(milliseconds: 350);
const _serviceActionDelay = Duration(milliseconds: 250);

Future<void> pumpMapScreen(WidgetTester tester) async {
  await tester.pumpWidget(buildTestApp(home: const MapScreen()));
  await tester.pump(_incidentLoadDelay);
}

MarkerLayer markerLayer(WidgetTester tester) {
  return tester.widget<MarkerLayer>(find.byType(MarkerLayer));
}

GestureDetector firstMarkerTapTarget(WidgetTester tester) {
  return markerLayer(tester).markers.first.child as GestureDetector;
}

Future<void> openFirstIncidentSheet(WidgetTester tester) async {
  firstMarkerTapTarget(tester).onTap!();
  await tester.pump();
  await tester.pumpAndSettle();
}

Key sheetActionKey(String label) {
  return switch (label) {
    'ON THE WAY' => const Key('incident-on-the-way-button'),
    'REACHED' => const Key('incident-reached-button'),
    'VERIFY' => const Key('incident-verify-button'),
    'REQUEST RESOURCES' => const Key('request-resources-button'),
    'ADD OBSERVATION' => const Key('add-observation-button'),
    _ => throw ArgumentError.value(label, 'label', 'Unknown sheet action'),
  };
}

Future<void> pressSheetAction(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();

  final buttonFinder = find.byKey(sheetActionKey(label));
  expect(buttonFinder, findsOneWidget);

  await tester.tap(buttonFinder);
  await tester.pumpAndSettle();
}

Future<void> drainIncidentService(WidgetTester tester) async {
  await tester.pump(_serviceActionDelay);
  await tester.pumpAndSettle();
}

Future<void> pressTextButton(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();

  final buttonFinder = find.widgetWithText(TextButton, label);
  expect(buttonFinder, findsOneWidget);

  await tester.tap(buttonFinder);
  await tester.pumpAndSettle();
}

Future<void> pressKeyedTextButton(WidgetTester tester, Key key) async {
  await tester.pump();

  final buttonFinder = find.byKey(key);
  expect(buttonFinder, findsOneWidget);

  await tester.tap(buttonFinder);
  await tester.pump();
}

Future<Incident> waitForIncidentUpdate(String incidentId) {
  return IncidentService.updates.firstWhere(
    (incident) => incident.id == incidentId,
  );
}

Future<bool> emitsIncidentUpdateDuring(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var emitted = false;
  final sub = IncidentService.updates.listen((_) => emitted = true);

  await action();
  await tester.pump();
  await sub.cancel();

  return emitted;
}

void main() {
  setUpAll(configureTestFonts);
  setUp(AuthService.signOut);

  group('MapScreen', () {
    testWidgets('renders map, legend, controls, and summary', (tester) async {
      await pumpMapScreen(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('MATRIX'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('ELEVATED'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('SHELTER'), findsOneWidget);
      expect(find.text('ACTIVE AO SUMMARY'), findsOneWidget);
      expect(find.text('PERSONNEL'), findsOneWidget);
      expect(find.text('INCIDENTS'), findsOneWidget);
    });

    testWidgets('incident marker layer is configured after incidents load', (tester) async {
      await pumpMapScreen(tester);

      expect(markerLayer(tester).markers, hasLength(2));
    });

    testWidgets('priority incident action shows feedback', (tester) async {
      await pumpMapScreen(tester);

      final dispatchTap = find.byKey(const Key('priority-dispatch-button'));

      expect(dispatchTap, findsOneWidget);
      tester.widget<InkWell>(dispatchTap).onTap!();
      await tester.pump();

      expect(find.text('Dispatching unit to ZONE-ALPHA...'), findsOneWidget);
    });

    testWidgets('layer button shows feedback', (tester) async {
      await pumpMapScreen(tester);

      final button = tester.widget<IconButton>(
        find.byKey(const Key('map-layers-button')),
      );
      expect(button.onPressed, isNotNull);

      button.onPressed!();
      await tester.pump();

      expect(find.text('Layers menu coming soon'), findsOneWidget);
    });

    testWidgets('zoom and location controls are callable', (tester) async {
      await pumpMapScreen(tester);

      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      ).onPressed!();
      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      ).onPressed!();
      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.my_location),
      ).onPressed!();
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('bottom navigation opens dashboard route', (tester) async {
      await pumpMapScreen(tester);

      tester.widget<BottomNav>(find.byType(BottomNav)).onTap(0);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);
    });

    testWidgets('marker callback opens incident sheet', (tester) async {
      await pumpMapScreen(tester);

      await openFirstIncidentSheet(tester);

      expect(find.text('INC-1001'), findsOneWidget);
      expect(find.text('ON THE WAY'), findsOneWidget);
      expect(find.text('REACHED'), findsOneWidget);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(find.text('REQUEST RESOURCES'), findsOneWidget);
      expect(find.text('ADD OBSERVATION'), findsOneWidget);
    });

    testWidgets('incident sheet status actions update incidents', (tester) async {
      await pumpMapScreen(tester);

      await openFirstIncidentSheet(tester);
      final onTheWayUpdate = waitForIncidentUpdate('INC-1001');
      await pressSheetAction(tester, 'ON THE WAY');
      expect((await onTheWayUpdate).status, IncidentStatus.onTheWay);
      await drainIncidentService(tester);

      await openFirstIncidentSheet(tester);
      final reachedUpdate = waitForIncidentUpdate('INC-1001');
      await pressSheetAction(tester, 'REACHED');
      expect((await reachedUpdate).status, IncidentStatus.reached);
      await drainIncidentService(tester);

      await openFirstIncidentSheet(tester);
      final verifiedUpdate = waitForIncidentUpdate('INC-1001');
      await pressSheetAction(tester, 'VERIFY');
      expect((await verifiedUpdate).status, IncidentStatus.verified);
      await drainIncidentService(tester);
    });

    testWidgets('priority incident visibility button shows feedback', (tester) async {
      await pumpMapScreen(tester);

      final visibilityTap = find.byKey(const Key('priority-visibility-button'));

      expect(visibilityTap, findsOneWidget);
      tester.widget<GestureDetector>(visibilityTap).onTap!();
      await tester.pump();

      expect(find.text('Toggling incident visibility...'), findsOneWidget);
    });

    /*testWidgets('request resources dialog handles cancel and submit paths', (tester) async {
      await pumpMapScreen(tester);
      await openFirstIncidentSheet(tester);

      await pressSheetAction(tester, 'REQUEST RESOURCES');
      expect(find.text('Request Resources'), findsOneWidget);

      final emittedOnCancel = await emitsIncidentUpdateDuring(
        tester,
        () => pressKeyedTextButton(
          tester,
          const Key('request-resources-cancel-button'),
        ),
      );
      expect(emittedOnCancel, isFalse);
      expect(find.text('Resource request sent'), findsNothing);

      await pressSheetAction(tester, 'REQUEST RESOURCES');
      await tester.enterText(
        find.byKey(const Key('request-resources-input')),
        'Ambulance, Medical Team',
      );

      final requestUpdate = waitForIncidentUpdate('INC-1001');
      await pressKeyedTextButton(
        tester,
        const Key('request-resources-send-button'),
      );
      final incident = await requestUpdate;
      expect(incident.status, IncidentStatus.needResources);
      expect(incident.description, contains('Ambulance, Medical Team'));
      await drainIncidentService(tester);
    });

    testWidgets('add observation dialog handles empty and save paths', (tester) async {
      await pumpMapScreen(tester);
      await openFirstIncidentSheet(tester);

      await pressSheetAction(tester, 'ADD OBSERVATION');
      expect(find.text('Add Observation'), findsOneWidget);

      final emittedOnEmptySave = await emitsIncidentUpdateDuring(
        tester,
        () => pressKeyedTextButton(
          tester,
          const Key('add-observation-save-button'),
        ),
      );
      expect(emittedOnEmptySave, isFalse);
      expect(find.text('Observation added'), findsNothing);

      await pressSheetAction(tester, 'ADD OBSERVATION');
      await tester.enterText(
        find.byKey(const Key('add-observation-input')),
        'Bridge access blocked',
      );

      final observationUpdate = waitForIncidentUpdate('INC-1001');
      await pressKeyedTextButton(
        tester,
        const Key('add-observation-save-button'),
      );
      final incident = await observationUpdate;
      expect(incident.description, contains('[OBS] Bridge access blocked'));
      await drainIncidentService(tester);
    });*/
  });
}
