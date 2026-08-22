class StateIsolateCount {
  final String state;
  final int count;

  const StateIsolateCount({required this.state, required this.count});

  factory StateIsolateCount.fromJson(Map<String, dynamic> json) => StateIsolateCount(
        state: json['state'] as String? ?? 'Unknown',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class PathogenStat {
  final String pathogen;
  final int count;
  final double resistanceRate;

  const PathogenStat({
    required this.pathogen,
    required this.count,
    required this.resistanceRate,
  });

  factory PathogenStat.fromJson(Map<String, dynamic> json) => PathogenStat(
        pathogen: json['pathogen'] as String? ?? 'Unknown',
        count: (json['count'] as num?)?.toInt() ?? 0,
        resistanceRate: (json['resistance_rate'] as num?)?.toDouble() ?? 0.0,
      );
}

class ResistanceCombo {
  final String pathogen;
  final String antibiotic;
  final double resistanceRate;
  final String trend;
  final int isolates;
  final int districts;
  final String riskLevel;

  const ResistanceCombo({
    required this.pathogen,
    required this.antibiotic,
    required this.resistanceRate,
    required this.trend,
    required this.isolates,
    required this.districts,
    required this.riskLevel,
  });

  factory ResistanceCombo.fromJson(Map<String, dynamic> json) => ResistanceCombo(
        pathogen: json['pathogen'] as String? ?? '',
        antibiotic: json['antibiotic'] as String? ?? '',
        resistanceRate: (json['resistance_rate'] as num?)?.toDouble() ?? 0.0,
        trend: json['trend'] as String? ?? '0%',
        isolates: (json['isolates'] as num?)?.toInt() ?? 0,
        districts: (json['districts'] as num?)?.toInt() ?? 0,
        riskLevel: json['risk_level'] as String? ?? 'Medium',
      );
}

class DiseaseTrendPoint {
  final String date;
  final int dengue;
  final int malaria;
  final int typhoid;
  final int pneumonia;
  final int viralFever;

  const DiseaseTrendPoint({
    required this.date,
    required this.dengue,
    required this.malaria,
    required this.typhoid,
    required this.pneumonia,
    required this.viralFever,
  });

  factory DiseaseTrendPoint.fromJson(Map<String, dynamic> json) => DiseaseTrendPoint(
        date: json['date'] as String? ?? '',
        dengue: (json['dengue'] as num?)?.toInt() ?? 0,
        malaria: (json['malaria'] as num?)?.toInt() ?? 0,
        typhoid: (json['typhoid'] as num?)?.toInt() ?? 0,
        pneumonia: (json['pneumonia'] as num?)?.toInt() ?? 0,
        viralFever: (json['viral_fever'] as num?)?.toInt() ?? 0,
      );
}

class EcoliTrendPoint {
  final String date;
  final double resistanceRate;
  final double ewma;
  final double cusum;

  const EcoliTrendPoint({
    required this.date,
    required this.resistanceRate,
    required this.ewma,
    required this.cusum,
  });

  factory EcoliTrendPoint.fromJson(Map<String, dynamic> json) => EcoliTrendPoint(
        date: json['date'] as String? ?? '',
        resistanceRate: (json['resistance_rate'] as num?)?.toDouble() ?? 0.0,
        ewma: (json['ewma'] as num?)?.toDouble() ?? 0.0,
        cusum: (json['cusum'] as num?)?.toDouble() ?? 0.0,
      );
}

class AdminAlert {
  final String alertId;
  final String type;
  final String pathogen;
  final String location;
  final int riskScore;
  final String severity;
  final String detectedAt;
  final String status;

  const AdminAlert({
    required this.alertId,
    required this.type,
    required this.pathogen,
    required this.location,
    required this.riskScore,
    required this.severity,
    required this.detectedAt,
    required this.status,
  });

  factory AdminAlert.fromJson(Map<String, dynamic> json) => AdminAlert(
        alertId: json['alert_id'] as String? ?? '',
        type: json['type'] as String? ?? 'AMR',
        pathogen: json['pathogen'] as String? ?? '',
        location: json['location'] as String? ?? '',
        riskScore: (json['risk_score'] as num?)?.toInt() ?? 50,
        severity: json['severity'] as String? ?? 'Medium',
        detectedAt: json['detected_at'] as String? ?? '',
        status: json['status'] as String? ?? 'New',
      );
}

class AdminKpiData {
  final int totalCases;
  final String totalCasesChange;
  final int totalFacilities;
  final String totalFacilitiesChange;
  final double amrResistanceRate;
  final String amrRateChange;
  final int activeAlerts;
  final String activeAlertsChange;

  const AdminKpiData({
    required this.totalCases,
    required this.totalCasesChange,
    required this.totalFacilities,
    required this.totalFacilitiesChange,
    required this.amrResistanceRate,
    required this.amrRateChange,
    required this.activeAlerts,
    required this.activeAlertsChange,
  });

  factory AdminKpiData.fromJson(Map<String, dynamic> json) => AdminKpiData(
        totalCases: (json['total_cases'] as num?)?.toInt() ?? 24532,
        totalCasesChange: json['total_cases_change'] as String? ?? '+12.4%',
        totalFacilities: (json['total_facilities'] as num?)?.toInt() ?? 1248,
        totalFacilitiesChange: json['total_facilities_change'] as String? ?? '+8.7%',
        amrResistanceRate: (json['amr_resistance_rate'] as num?)?.toDouble() ?? 28.7,
        amrRateChange: json['amr_rate_change'] as String? ?? '+6.3%',
        activeAlerts: (json['active_alerts'] as num?)?.toInt() ?? 12,
        activeAlertsChange: json['active_alerts_change'] as String? ?? '+3 new',
      );
}

class AdminQuickStats {
  final int reportsReceived;
  final int labTestsCompleted;
  final int newFacilities;
  final String districtsReporting;

  const AdminQuickStats({
    required this.reportsReceived,
    required this.labTestsCompleted,
    required this.newFacilities,
    required this.districtsReporting,
  });

  factory AdminQuickStats.fromJson(Map<String, dynamic> json) => AdminQuickStats(
        reportsReceived: (json['reports_received'] as num?)?.toInt() ?? 3462,
        labTestsCompleted: (json['lab_tests_completed'] as num?)?.toInt() ?? 7812,
        newFacilities: (json['new_facilities'] as num?)?.toInt() ?? 56,
        districtsReporting: json['districts_reporting'] as String? ?? '412 / 713',
      );
}

class AdminDashboardData {
  final int totalIsolatesProcessed;
  final AdminKpiData kpi;
  final List<StateIsolateCount> stateCounts;
  final List<PathogenStat> topPathogens;
  final List<ResistanceCombo> topResistanceCombos;
  final List<DiseaseTrendPoint> diseaseTrends;
  final List<EcoliTrendPoint> ecoliTrend;
  final List<AdminAlert> recentAlerts;
  final AdminQuickStats quickStats;

  const AdminDashboardData({
    required this.totalIsolatesProcessed,
    required this.kpi,
    required this.stateCounts,
    required this.topPathogens,
    required this.topResistanceCombos,
    required this.diseaseTrends,
    required this.ecoliTrend,
    required this.recentAlerts,
    required this.quickStats,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      totalIsolatesProcessed: (json['total_isolates_processed'] as num?)?.toInt() ?? 1121,
      kpi: AdminKpiData.fromJson(json['kpi'] as Map<String, dynamic>? ?? {}),
      stateCounts: (json['state_counts'] as List<dynamic>?)
              ?.map((e) => StateIsolateCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topPathogens: (json['top_pathogens'] as List<dynamic>?)
              ?.map((e) => PathogenStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topResistanceCombos: (json['top_resistance_combos'] as List<dynamic>?)
              ?.map((e) => ResistanceCombo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      diseaseTrends: (json['disease_trends'] as List<dynamic>?)
              ?.map((e) => DiseaseTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ecoliTrend: (json['ecoli_trend'] as List<dynamic>?)
              ?.map((e) => EcoliTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentAlerts: (json['recent_alerts'] as List<dynamic>?)
              ?.map((e) => AdminAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quickStats: AdminQuickStats.fromJson(json['quick_stats'] as Map<String, dynamic>? ?? {}),
    );
  }
}
