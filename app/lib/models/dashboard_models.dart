class DashboardSummary {
  final int patientsToday;
  final int reportsSubmittedTotal;
  final int activeConditions;

  const DashboardSummary({
    required this.patientsToday,
    required this.reportsSubmittedTotal,
    required this.activeConditions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        patientsToday: json['patients_today'] as int? ?? 0,
        reportsSubmittedTotal: json['reports_submitted_total'] as int? ?? 0,
        activeConditions: json['active_conditions'] as int? ?? 0,
      );

  static const zero =
      DashboardSummary(patientsToday: 0, reportsSubmittedTotal: 0, activeConditions: 0);
}

class ReportSummary {
  final String reportId;
  final String reportDate;
  final String? diagnosis;
  final String? diagnosisStatus;
  final String? complaints;

  const ReportSummary({
    required this.reportId,
    required this.reportDate,
    this.diagnosis,
    this.diagnosisStatus,
    this.complaints,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
        reportId: json['report_id'] as String,
        reportDate: json['report_date'] as String,
        diagnosis: json['diagnosis'] as String?,
        diagnosisStatus: json['diagnosis_status'] as String?,
        complaints: json['complaints'] as String?,
      );
}

/// Dashboard sections not yet served by the analytics API (Stage 8 of the
/// surveillance plan). Placeholder data so the layout is real and reviewable
/// before that endpoint exists; swapped for a live provider once it does.
class QueuePatient {
  final String name;
  final String ageGender;
  final String condition;
  final String status;
  final String lastVisit;

  const QueuePatient({
    required this.name,
    required this.ageGender,
    required this.condition,
    required this.status,
    required this.lastVisit,
  });
}

class FacilitySignal {
  final String category;
  final String change;
  final String level;

  const FacilitySignal({required this.category, required this.change, required this.level});
}

class OutbreakAlert {
  final String title;
  final String severity;
  final String detail;

  const OutbreakAlert({required this.title, required this.severity, required this.detail});
}

class TrendSeries {
  final String name;
  final List<double> values;

  const TrendSeries({required this.name, required this.values});
}
