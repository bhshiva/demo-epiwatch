import 'package:epiwatch/models/session.dart';
import 'package:epiwatch/theme/app_theme.dart';
import 'package:epiwatch/workspaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Session _session(String role) => Session(
      accessToken: 'tok',
      role: role,
      doctorId: 'd1',
      name: switch (role) {
        'lab' => 'Priya Nair',
        'health_authority' => 'Dr. Meera Iyer',
        'admin' => 'Ravi Kulkarni',
        _ => 'Dr. Asha Rao',
      },
      // health_authority/admin aren't tied to one facility.
      facilityId: (role == 'health_authority' || role == 'admin') ? null : 'f1',
    );

/// Every destination label across all four roles, so a test can assert that
/// a given role's screen shows ONLY its own labels -- the reported WPF bug
/// was a lab user seeing the clinician workspace, and this project now has
/// four roles to keep mutually exclusive, not two.
const _allRoleLabels = [
  'Patient Records',
  'Submit Report',
  'Worklist',
  'Culture & AST',
  'Live Surveillance',
  'Disease Trends',
  'Geographic Clusters',
  'National Statistics',
  'Alerts',
  'Applications',
];

const _healthAuthorityLabels = [
  'Live Surveillance',
  'Disease Trends',
  'Geographic Clusters',
  'National Statistics',
  'Alerts',
];

Future<void> _pumpWorkspace(WidgetTester tester, Session session,
    {Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.build(), home: workspaceFor(session)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('role decides the workspace', () {
    testWidgets('a lab user gets the lab destinations and badge',
        (tester) async {
      await _pumpWorkspace(tester, _session('lab'));

      expect(find.text('LAB'), findsOneWidget);
      expect(find.text('Microbiologist: Priya Nair'), findsOneWidget);
      expect(find.text('Lab Dashboard'), findsWidgets);
      expect(find.text('Worklist'), findsOneWidget);
      expect(find.text('Culture & AST'), findsOneWidget);

      // The reported WPF bug: a lab user seeing the clinician workspace.
      // Now four roles, so check every other role's labels, not just
      // doctor's.
      for (final label in _allRoleLabels) {
        if (label == 'Worklist' || label == 'Culture & AST') continue;
        expect(find.text(label), findsNothing, reason: '$label leaked into the lab workspace');
      }
    });

    testWidgets('a doctor gets the clinician destinations', (tester) async {
      await _pumpWorkspace(tester, _session('doctor'));

      expect(find.text('DOCTOR'), findsOneWidget);
      expect(find.text('Clinician: Dr. Asha Rao'), findsOneWidget);
      expect(find.text('Patient Records'), findsOneWidget);
      for (final label in _allRoleLabels) {
        if (label == 'Patient Records' || label == 'Submit Report') continue;
        expect(find.text(label), findsNothing, reason: '$label leaked into the doctor workspace');
      }
    });

    testWidgets('a health authority user gets the surveillance destinations and badge',
        (tester) async {
      await _pumpWorkspace(tester, _session('health_authority'));

      expect(find.text('HEALTH AUTHORITY'), findsOneWidget);
      expect(find.text('Surveillance Officer: Dr. Meera Iyer'), findsOneWidget);
      for (final label in _healthAuthorityLabels) {
        expect(find.text(label), findsWidgets, reason: '$label missing from the health authority workspace');
      }
      for (final label in _allRoleLabels) {
        if (_healthAuthorityLabels.contains(label)) continue;
        expect(find.text(label), findsNothing,
            reason: '$label leaked into the health authority workspace');
      }
    });

    testWidgets('an admin user gets the applications destination and badge',
        (tester) async {
      await _pumpWorkspace(tester, _session('admin'));

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Facility Onboarding: Ravi Kulkarni'), findsOneWidget);
      expect(find.text('Applications'), findsWidgets);
      for (final label in _allRoleLabels) {
        if (label == 'Applications') continue;
        expect(find.text(label), findsNothing, reason: '$label leaked into the admin workspace');
      }
    });

    testWidgets('an unrecognised role falls back to the doctor workspace',
        (tester) async {
      await _pumpWorkspace(tester, _session('analyst'));

      expect(find.text('DOCTOR'), findsOneWidget);
      expect(find.text('Worklist'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('a wide window shows the sidebar and no bottom bar',
        (tester) async {
      await _pumpWorkspace(tester, _session('lab'));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('a phone-width window shows a bottom bar instead',
        (tester) async {
      await _pumpWorkspace(tester, _session('lab'),
          size: const Size(420, 900));

      expect(find.byType(NavigationBar), findsOneWidget);
      // Destinations survive the switch to the compact layout.
      expect(find.text('Worklist'), findsWidgets);
    });
  });

  testWidgets('tapping a destination swaps the content', (tester) async {
    await _pumpWorkspace(tester, _session('lab'));

    expect(find.text('Laboratory Workspace'), findsOneWidget);
    await tester.tap(find.text('Culture & AST'));
    await tester.pumpAndSettle();

    expect(find.text('Record Culture & Susceptibility'), findsOneWidget);
  });
}
