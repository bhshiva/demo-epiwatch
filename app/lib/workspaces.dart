import 'package:flutter/material.dart';
import 'models/nav_destination.dart';
import 'models/session.dart';
import 'screens/admin_applications_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/disease_trends_screen.dart';
import 'screens/geographic_clusters_screen.dart';
import 'screens/health_authority_dashboard_screen.dart';
import 'screens/lab_dashboard_screen.dart';
import 'screens/lab_worklist_screen.dart';
import 'screens/national_statistics_screen.dart';
import 'screens/patient_records_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/submit_isolate_screen.dart';
import 'screens/submit_report_screen.dart';

/// Maps a signed-in role to the workspace it gets.
///
/// The server enforces the same boundary on every request; this only decides
/// what a role is offered. An unrecognised role falls back to the doctor
/// workspace, which is the least-privileged of the roles.
ShellScreen workspaceFor(Session session) {
  if (session.isHealthAuthority) return _healthAuthorityWorkspace(session.name);
  if (session.isAdmin) return _adminWorkspace(session.name);
  if (session.isLab) return _labWorkspace(session.name);
  return _doctorWorkspace(session.name);
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
          builder: (context) => DashboardScreen(
            doctorName: userName,
            facilityName: 'Sunrise Multispeciality Clinic',
            onSubmitReport: () => ShellNav.of(context).navigateTo('submit'),
            onViewRecords: () => ShellNav.of(context).navigateTo('records'),
          ),
        ),
        NavDestination(
          key: 'records',
          label: 'Patient Records',
          icon: Icons.folder_shared_outlined,
          builder: (_) => const PatientRecordsScreen(),
        ),
        NavDestination(
          key: 'submit',
          label: 'Submit Report',
          icon: Icons.assignment_outlined,
          builder: (_) => const SubmitReportScreen(),
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
          builder: (context) => LabDashboardScreen(
            userName: userName,
            onRecordIsolate: () => ShellNav.of(context).navigateTo('submit-isolate'),
          ),
        ),
        NavDestination(
          key: 'worklist',
          label: 'Worklist',
          icon: Icons.list_alt_outlined,
          builder: (_) => const LabWorklistScreen(),
        ),
        NavDestination(
          key: 'submit-isolate',
          label: 'Culture & AST',
          icon: Icons.science_outlined,
          builder: (_) => const SubmitIsolateScreen(),
        ),
      ],
    );

ShellScreen _healthAuthorityWorkspace(String userName) => ShellScreen(
      roleLabel: 'HEALTH AUTHORITY',
      roleCaption: 'Surveillance Officer',
      userName: userName,
      destinations: [
        NavDestination(
          key: 'live-surveillance',
          label: 'Live Surveillance',
          icon: Icons.podcasts_outlined,
          builder: (_) => HealthAuthorityDashboardScreen(userName: userName),
        ),
        NavDestination(
          key: 'disease-trends',
          label: 'Disease Trends',
          icon: Icons.show_chart,
          builder: (_) => const DiseaseTrendsScreen(),
        ),
        NavDestination(
          key: 'geographic-clusters',
          label: 'Geographic Clusters',
          icon: Icons.map_outlined,
          builder: (_) => const GeographicClustersScreen(),
        ),
        NavDestination(
          key: 'amr-watch',
          label: 'National Statistics',
          icon: Icons.bar_chart_outlined,
          builder: (_) => const NationalStatisticsScreen(),
        ),
        NavDestination(
          key: 'alerts',
          label: 'Alerts',
          icon: Icons.warning_amber_outlined,
          builder: (_) => const AlertsScreen(),
        ),
      ],
    );

ShellScreen _adminWorkspace(String userName) => ShellScreen(
      roleLabel: 'ADMIN',
      roleCaption: 'Facility Onboarding',
      userName: userName,
      destinations: [
        NavDestination(
          key: 'applications',
          label: 'Applications',
          icon: Icons.fact_check_outlined,
          builder: (_) => AdminApplicationsScreen(userName: userName),
        ),
      ],
    );
