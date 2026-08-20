import 'package:flutter/material.dart';
import 'models/nav_destination.dart';
import 'models/session.dart';
import 'screens/placeholder_screen.dart';
import 'screens/shell_screen.dart';

/// Maps a signed-in role to the workspace it gets.
///
/// The server enforces the same boundary on every request; this only decides
/// what a role is offered. An unrecognised role falls back to the doctor
/// workspace, which is the least-privileged of the two.
ShellScreen workspaceFor(Session session) {
  return session.isLab
      ? _labWorkspace(session.name)
      : _doctorWorkspace(session.name);
}

ShellScreen _doctorWorkspace(String userName) => ShellScreen(
      roleLabel: 'DOCTOR',
      roleCaption: 'Clinician',
      userName: userName,
      destinations: [
        NavDestination(
          key: 'dashboard',
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Doctor Dashboard'),
        ),
        NavDestination(
          key: 'records',
          label: 'Patient Records',
          icon: Icons.folder_shared_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Patient Records'),
        ),
        NavDestination(
          key: 'submit',
          label: 'Submit Report',
          icon: Icons.assignment_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Submit Report'),
        ),
      ],
    );

ShellScreen _labWorkspace(String userName) => ShellScreen(
      roleLabel: 'LAB',
      roleCaption: 'Microbiologist',
      userName: userName,
      destinations: [
        NavDestination(
          key: 'lab-dashboard',
          label: 'Lab Dashboard',
          icon: Icons.biotech_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Lab Dashboard'),
        ),
        NavDestination(
          key: 'worklist',
          label: 'Worklist',
          icon: Icons.list_alt_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Culture Worklist'),
        ),
        NavDestination(
          key: 'submit-isolate',
          label: 'Culture & AST',
          icon: Icons.science_outlined,
          builder: (_) => const PlaceholderScreen(title: 'Record Culture & AST'),
        ),
      ],
    );
