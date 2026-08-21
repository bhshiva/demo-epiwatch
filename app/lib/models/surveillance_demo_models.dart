/// Illustrative-only models for Health Authority UI sections that have no
/// real detection engine behind them yet (see ML_PLAN.md, kept local/
/// uncommitted -- EWMA/CUSUM/Isolation Forest/graph-ML anomaly detection is
/// deliberately unbuilt). Every screen that renders these must say so
/// on-screen, the same way DemoData is used on the doctor dashboard.
class EmergingSignal {
  final String severity; // 'CRITICAL' | 'HIGH' | 'MEDIUM'
  final String title;
  final String region;
  final String detectedAgo;
  final String confidenceLabel; // e.g. 'High (92%)'
  final String deviationLabel; // e.g. '+38% baseline'

  const EmergingSignal({
    required this.severity,
    required this.title,
    required this.region,
    required this.detectedAgo,
    required this.confidenceLabel,
    required this.deviationLabel,
  });
}

class GeographicCluster {
  final String title;
  final String region;
  final String priority; // 'HIGH PRIORITY' | 'MEDIUM PRIORITY'
  final String detectedAt;
  final int confidencePercent;
  final String description;
  final int facilityCount;
  final int affectedDistricts;
  final int signalDurationDays;
  final int expectedPerWeek;
  final int currentPerWeek;
  final String recommendation;

  const GeographicCluster({
    required this.title,
    required this.region,
    required this.priority,
    required this.detectedAt,
    required this.confidencePercent,
    required this.description,
    required this.facilityCount,
    required this.affectedDistricts,
    required this.signalDurationDays,
    required this.expectedPerWeek,
    required this.currentPerWeek,
    required this.recommendation,
  });

  double get reportingIncreasePercent =>
      expectedPerWeek == 0 ? 0 : (currentPerWeek - expectedPerWeek) / expectedPerWeek * 100;
}

class SurveillanceAlert {
  final String id;
  final String severity; // 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'RESOLVED'
  final String title;
  final String region;
  final String detectedAgo;
  final String summary;
  final int confidencePercent;
  final String status; // 'Needs Review' | 'Assigned' | 'Acknowledged' | 'Resolved'
  final int contributingSites;

  const SurveillanceAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.region,
    required this.detectedAgo,
    required this.summary,
    required this.confidencePercent,
    required this.status,
    required this.contributingSites,
  });
}
