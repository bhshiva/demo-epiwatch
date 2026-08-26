import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surveillance_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class SurveillanceDashboardState {
  final List<DiseaseDailyPoint> diseaseDaily;
  final List<SurveillanceMetric> resistanceRates;
  final List<FacilityGeo> facilities;
  final List<DistrictSummary> districts;
  final List<RiskScore> riskScores;
  final List<Alert> alerts;
  final SurveillanceSummary summary;
  final bool isBusy;
  final String? error;

  const SurveillanceDashboardState({
    this.diseaseDaily = const [],
    this.resistanceRates = const [],
    this.facilities = const [],
    this.districts = const [],
    this.riskScores = const [],
    this.alerts = const [],
    this.summary = const SurveillanceSummary(facilitiesReporting: 0, reportsToday: 0),
    this.isBusy = false,
    this.error,
  });

  SurveillanceDashboardState copyWith({
    List<DiseaseDailyPoint>? diseaseDaily,
    List<SurveillanceMetric>? resistanceRates,
    List<FacilityGeo>? facilities,
    List<DistrictSummary>? districts,
    List<RiskScore>? riskScores,
    List<Alert>? alerts,
    SurveillanceSummary? summary,
    bool? isBusy,
    String? error,
  }) =>
      SurveillanceDashboardState(
        diseaseDaily: diseaseDaily ?? this.diseaseDaily,
        resistanceRates: resistanceRates ?? this.resistanceRates,
        facilities: facilities ?? this.facilities,
        districts: districts ?? this.districts,
        riskScores: riskScores ?? this.riskScores,
        alerts: alerts ?? this.alerts,
        summary: summary ?? this.summary,
        isBusy: isBusy ?? this.isBusy,
        error: error,
      );

  /// Facilities ranked by recent case count, highest first -- the simplest
  /// possible "watch list" until the real detection engine (EWMA/CUSUM/
  /// Isolation Forest risk scoring, deliberately out of scope here -- see
  /// ML_PLAN.md) exists. Not an alert, just a sort.
  List<FacilityGeo> get watchList {
    final sorted = [...facilities]..sort((a, b) => b.recentCaseCount.compareTo(a.recentCaseCount));
    return sorted.take(5).where((f) => f.recentCaseCount > 0).toList();
  }
}

final surveillanceDashboardProvider =
    NotifierProvider<SurveillanceDashboardNotifier, SurveillanceDashboardState>(
        SurveillanceDashboardNotifier.new);

class SurveillanceDashboardNotifier extends Notifier<SurveillanceDashboardState> {
  @override
  SurveillanceDashboardState build() => const SurveillanceDashboardState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);

    try {
      final results = await Future.wait([
        api.getDiseaseDaily().catchError((_) => <DiseaseDailyPoint>[]),
        api.getSurveillanceMetrics('resistance_rate').catchError((_) => <SurveillanceMetric>[]),
        api.getFacilitiesGeo().catchError((_) => <FacilityGeo>[]),
        api.getDistrictSummaries().catchError((_) => <DistrictSummary>[]),
        api.getSurveillanceSummary().catchError((_) => const SurveillanceSummary(facilitiesReporting: 0, reportsToday: 0)),
        api.getRiskScores().catchError((_) => <RiskScore>[]),
        api.getAlerts().catchError((_) => <Alert>[]),
      ]);

      state = SurveillanceDashboardState(
        diseaseDaily: results[0] as List<DiseaseDailyPoint>,
        resistanceRates: results[1] as List<SurveillanceMetric>,
        facilities: results[2] as List<FacilityGeo>,
        districts: results[3] as List<DistrictSummary>,
        summary: results[4] as SurveillanceSummary,
        riskScores: results[5] as List<RiskScore>,
        alerts: results[6] as List<Alert>,
        isBusy: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }
}
