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
      name: role == 'lab' ? 'Priya Nair' : 'Dr. Asha Rao',
      facilityId: 'f1',
    );

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
      expect(find.text('Patient Records'), findsNothing);
      expect(find.text('Submit Report'), findsNothing);
    });

    testWidgets('a doctor gets the clinician destinations', (tester) async {
      await _pumpWorkspace(tester, _session('doctor'));

      expect(find.text('DOCTOR'), findsOneWidget);
      expect(find.text('Clinician: Dr. Asha Rao'), findsOneWidget);
      expect(find.text('Patient Records'), findsOneWidget);
      expect(find.text('Worklist'), findsNothing);
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
