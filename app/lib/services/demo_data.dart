import '../models/dashboard_models.dart';

/// Static fallback for dashboard sections not yet served by the analytics
/// API, so the dashboard renders before those endpoints exist. Ported
/// verbatim from StaticDemoDataProvider in the WPF client.
abstract final class DemoData {
  static const patientQueue = [
    QueuePatient(
        name: 'Rohan Deshmukh',
        ageGender: '34 / M',
        condition: 'Influenza-like Illness',
        status: 'Suspected',
        lastVisit: '2 hours ago'),
    QueuePatient(
        name: 'Sunita Kadam',
        ageGender: '58 / F',
        condition: 'Influenza-like Illness',
        status: 'Confirmed',
        lastVisit: '4 hours ago'),
    QueuePatient(
        name: 'Aarav Mehta',
        ageGender: '7 / M',
        condition: 'Acute Gastroenteritis',
        status: 'Suspected',
        lastVisit: 'Yesterday'),
    QueuePatient(
        name: 'Fatima Sheikh',
        ageGender: '29 / F',
        condition: 'Dengue Fever',
        status: 'Probable',
        lastVisit: 'Yesterday'),
    QueuePatient(
        name: 'Vikram Joshi',
        ageGender: '45 / M',
        condition: 'Urinary Tract Infection',
        status: 'Confirmed',
        lastVisit: '2 days ago'),
    QueuePatient(
        name: 'Meera Iyer',
        ageGender: '62 / F',
        condition: 'Influenza-like Illness',
        status: 'Confirmed',
        lastVisit: '2 days ago'),
  ];

  static const facilitySignals = [
    FacilitySignal(category: 'Respiratory Symptoms', change: '+23% this week', level: 'Elevated'),
    FacilitySignal(category: 'Gastrointestinal', change: '-8% this week', level: 'Normal'),
    FacilitySignal(category: 'Febrile Illness', change: '+11% this week', level: 'Monitoring'),
  ];

  static const outbreakAlerts = [
    OutbreakAlert(
      title: 'Influenza-like Illness Outbreak Warning',
      severity: 'CRITICAL',
      detail:
          'Public health authorities have triggered an alert for elevated respiratory activity '
          'in the Mumbai Metropolitan Region. Request cultures / Rapid Antigen Tests for '
          'qualifying cases.',
    ),
    OutbreakAlert(
      title: 'AMR Signal - E. coli Reduced Susceptibility',
      severity: 'HIGH',
      detail: 'Karnataka Apex Lab reports rising Ciprofloxacin resistance in E. coli urinary '
          'isolates. Consider culture-guided prescribing for suspected UTIs.',
    ),
    OutbreakAlert(
      title: 'Dengue Fever Cluster (Resolved)',
      severity: 'RESOLVED',
      detail: 'Delhi Central Wards cluster has been resolved after vector control intervention. '
          'Continue routine reporting for febrile illness.',
    ),
  ];

  static const weeklyTrends = [
    TrendSeries(name: 'Fever', values: [7, 7, 6, 5, 4, 3, 3]),
    TrendSeries(name: 'Gastrointestinal', values: [4, 5, 5, 5, 5, 5, 5]),
    TrendSeries(name: 'Respiratory', values: [9, 12, 13, 13, 12, 10, 10]),
  ];

  static List<String> trendLabels() {
    final today = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', // ignore: comment_references
    ];
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return '${months[d.month - 1]} ${d.day}';
    });
  }
}
