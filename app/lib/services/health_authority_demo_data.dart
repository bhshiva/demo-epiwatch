import '../models/surveillance_demo_models.dart';

/// Illustrative placeholders for the anomaly-detection/clustering UI --
/// confidence percentages, deviation-from-baseline, and cluster
/// membership all require a real detection engine (EWMA/CUSUM/Isolation
/// Forest, or the graph-ML link-prediction/community-detection layer) that
/// is deliberately unbuilt (see ML_PLAN.md, kept local/uncommitted). This
/// mirrors DemoData's role on the doctor dashboard: lets the screens exist
/// and be reviewed for layout/interaction before real detection logic
/// exists to feed them, and is never rendered without an on-screen label
/// saying so.
abstract final class HealthAuthorityDemoData {
  static const emergingSignals = [
    EmergingSignal(
      severity: 'CRITICAL',
      title: 'Respiratory illness cluster',
      region: 'Mumbai Metropolitan Region',
      detectedAgo: '2h ago',
      confidenceLabel: 'High (92%)',
      deviationLabel: '+38% baseline',
    ),
    EmergingSignal(
      severity: 'HIGH',
      title: 'Atypical fever spike',
      region: 'Pune Metropolitan Region',
      detectedAgo: '4h ago',
      confidenceLabel: 'Medium (78%)',
      deviationLabel: '+22% baseline',
    ),
    EmergingSignal(
      severity: 'MEDIUM',
      title: 'Reduced Susceptibility — E. coli',
      region: 'Dharwad, Karnataka',
      detectedAgo: '1d ago',
      confidenceLabel: 'High (84%)',
      deviationLabel: '+12% resistance',
    ),
  ];

  static const geographicClusters = [
    GeographicCluster(
      title: 'Respiratory Illness Cluster Mumbai Metropolitan Region',
      region: 'Mumbai Metropolitan Region',
      priority: 'HIGH PRIORITY',
      detectedAt: '16 Aug 2026, 14:32',
      confidencePercent: 87,
      description: 'Potential cluster detected across central wards. Not a confirmed '
          'outbreak. Requires field verification.',
      facilityCount: 8,
      affectedDistricts: 3,
      signalDurationDays: 6,
      expectedPerWeek: 124,
      currentPerWeek: 171,
      recommendation: 'Review recent clinical trends across top contributing facilities '
          'to rule out artifact.',
    ),
  ];

  static const alerts = [
    SurveillanceAlert(
      id: 'ALT-ILI01',
      severity: 'CRITICAL',
      title: 'Influenza-like Illness',
      region: 'Mumbai Metropolitan Region',
      detectedAgo: '42 min ago',
      summary: '4 facilities reporting an unusual increase',
      confidencePercent: 92,
      status: 'Needs Review',
      contributingSites: 4,
    ),
    SurveillanceAlert(
      id: 'ALT-ECO02',
      severity: 'HIGH',
      title: 'Reduced Susceptibility — E. coli',
      region: 'Dharwad, Karnataka',
      detectedAgo: '3h ago',
      summary: '2 facilities reporting an unusual increase',
      confidencePercent: 78,
      status: 'Needs Review',
      contributingSites: 2,
    ),
    SurveillanceAlert(
      id: 'ALT-FEV03',
      severity: 'HIGH',
      title: 'Atypical fever spike',
      region: 'Pune Metropolitan Region',
      detectedAgo: '4h ago',
      summary: '3 facilities reporting an unusual increase',
      confidencePercent: 78,
      status: 'Assigned',
      contributingSites: 3,
    ),
    SurveillanceAlert(
      id: 'ALT-GI04',
      severity: 'MEDIUM',
      title: 'Gastrointestinal illness uptick',
      region: 'Nashik, Maharashtra',
      detectedAgo: '1d ago',
      summary: '2 facilities reporting an unusual increase',
      confidencePercent: 65,
      status: 'Acknowledged',
      contributingSites: 2,
    ),
    SurveillanceAlert(
      id: 'ALT-DEN05',
      severity: 'RESOLVED',
      title: 'Dengue Fever Cluster',
      region: 'Delhi Central Wards',
      detectedAgo: '6d ago',
      summary: 'Resolved after vector control intervention',
      confidencePercent: 88,
      status: 'Resolved',
      contributingSites: 5,
    ),
  ];
}
