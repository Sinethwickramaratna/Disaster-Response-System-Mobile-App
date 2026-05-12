import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/components/nav_bar.dart';
import 'package:command_mobile/models/incident.dart';
import 'package:command_mobile/models/user.dart';
import 'package:command_mobile/screens/map_screen.dart';
import 'package:command_mobile/screens/reports_screen.dart';
import 'package:command_mobile/services/auth_service.dart';
import 'package:command_mobile/services/incident_service.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(configureTestFonts);
  setUp(AuthService.signOut);

  group('ReportsScreen', () {
    testWidgets('loads reports list', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Field Reports'), findsOneWidget);
      expect(find.text('Flooding'), findsOneWidget);
      expect(find.text('Road Block'), findsOneWidget);
      expect(find.text('VERIFY'), findsWidgets);
      expect(find.text('REJECT'), findsWidgets);
    });

    testWidgets('filters are rendered and selectable', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('ASSIGNED'), findsOneWidget);
      expect(find.text('PRIORITY'), findsOneWidget);

      await tester.tap(find.text('PRIORITY'));
      await tester.pump();

      expect(find.text('PRIORITY'), findsOneWidget);
    });

    testWidgets('uses current user zone when loading reports', (tester) async {
      AuthService.authenticate('FO-A01', 'zonea001');

      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Flooding'), findsOneWidget);
      expect(find.text('Road Block'), findsNothing);
    });

    testWidgets('verify button updates report status and shows message', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('VERIFY').first);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Marked as verified'), findsOneWidget);
    });

    testWidgets('reject button updates report status and shows message', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      final update = IncidentService.updates.firstWhere(
        (incident) => incident.id == 'INC-1001',
      );
      await tester.tap(find.text('REJECT').first);
      await tester.pump(const Duration(milliseconds: 250));

      expect((await update).status, IncidentStatus.reported);
      expect(find.text('Marked as rejected'), findsOneWidget);
    });

    testWidgets('shows empty report list for unknown zone', (tester) async {
      AuthService.currentUser = User(
        serviceId: 'TEST-1',
        role: 'OFFICER',
        zone: 'ZONE-Z',
      );

      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Flooding'), findsNothing);
      expect(find.text('Road Block'), findsNothing);
      expect(find.text('VERIFY'), findsNothing);
    });

    testWidgets('bottom nav opens map route from reports', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 350));

      final nav = tester.widget<BottomNav>(find.byType(BottomNav));
      nav.onTap(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MapScreen), findsOneWidget);
    });
  });
}
