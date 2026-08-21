/// Health Authority surveillance models: all-facility, read-only.
///
/// Mirrors `DiseaseDailyPoint`, `SurveillanceMetricOut` and `FacilityGeo`
/// from the backend contract (`GET /surveillance/*`).
class DiseaseDailyPoint {
  final String reportDate;
  final String diagnosis;
  final int caseCount;

  const DiseaseDailyPoint({
    required this.reportDate,
    required this.diagnosis,
    required this.caseCount,
  });

  factory DiseaseDailyPoint.fromJson(Map<String, dynamic> json) => DiseaseDailyPoint(
        reportDate: json['report_date'] as String,
        diagnosis: json['diagnosis'] as String,
        caseCount: json['case_count'] as int,
      );
}

class SurveillanceMetric {
  final String? facilityId;
  final String? pathogen;
  final String? antibiotic;
  final String windowStart;
  final String windowEnd;
  final double value;
  final int sampleSize;

  const SurveillanceMetric({
    this.facilityId,
    this.pathogen,
    this.antibiotic,
    required this.windowStart,
    required this.windowEnd,
    required this.value,
    required this.sampleSize,
  });

  factory SurveillanceMetric.fromJson(Map<String, dynamic> json) => SurveillanceMetric(
        facilityId: json['facility_id'] as String?,
        pathogen: json['pathogen'] as String?,
        antibiotic: json['antibiotic'] as String?,
        windowStart: json['window_start'] as String,
        windowEnd: json['window_end'] as String,
        value: (json['value'] as num).toDouble(),
        sampleSize: json['sample_size'] as int,
      );
}

class FacilityGeo {
  final String facilityId;
  final String name;
  final String district;
  final String state;
  final double? latitude;
  final double? longitude;
  final int recentCaseCount;

  const FacilityGeo({
    required this.facilityId,
    required this.name,
    required this.district,
    required this.state,
    this.latitude,
    this.longitude,
    required this.recentCaseCount,
  });

  factory FacilityGeo.fromJson(Map<String, dynamic> json) => FacilityGeo(
        facilityId: json['facility_id'] as String,
        name: json['name'] as String,
        district: json['district'] as String,
        state: json['state'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        recentCaseCount: json['recent_case_count'] as int,
      );
}

/// Live (uncached, unbatched) headline counts -- see backend
/// surveillance.py's docstring on GET /surveillance/summary.
class SurveillanceSummary {
  final int facilitiesReporting;
  final int reportsToday;

  const SurveillanceSummary({required this.facilitiesReporting, required this.reportsToday});

  factory SurveillanceSummary.fromJson(Map<String, dynamic> json) => SurveillanceSummary(
        facilitiesReporting: json['facilities_reporting'] as int,
        reportsToday: json['reports_today'] as int,
      );
}

class DistrictSummary {
  final String district;
  final String state;
  final int facilityCount;
  final int recentCaseCount;

  const DistrictSummary({
    required this.district,
    required this.state,
    required this.facilityCount,
    required this.recentCaseCount,
  });

  factory DistrictSummary.fromJson(Map<String, dynamic> json) => DistrictSummary(
        district: json['district'] as String,
        state: json['state'] as String,
        facilityCount: json['facility_count'] as int,
        recentCaseCount: json['recent_case_count'] as int,
      );
}
