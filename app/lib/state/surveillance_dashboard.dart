import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surveillance_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class SurveillanceDashboardState {
  final List<DiseaseDailyPoint> diseaseDaily;
  final List<SurveillanceMetric> resistanceRates;
  final List<FacilityGeo> facilities;
  final bool isBusy;
  final String? error;

  const SurveillanceDashboardState({
    this.diseaseDaily = const [],
    this.resistanceRates = const [],
    this.facilities = const [],
    this.isBusy = false,
    this.error,
  });

  SurveillanceDashboardState copyWith({
    List<DiseaseDailyPoint>? diseaseDaily,
    List<SurveillanceMetric>? resistanceRates,
    List<FacilityGeo>? facilities,
    bool? isBusy,
    String? error,
  }) =>
      SurveillanceDashboardState(
        diseaseDaily: diseaseDaily ?? this.diseaseDaily,
        resistanceRates: resistanceRates ?? this.resistanceRates,
        facilities: facilities ?? this.facilities,
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
      final diseaseDaily = await api.getDiseaseDaily();
      final resistanceRates = await api.getSurveillanceMetrics('resistance_rate');
      final facilities = await api.getFacilitiesGeo();
      state = SurveillanceDashboardState(
        diseaseDaily: diseaseDaily,
        resistanceRates: resistanceRates,
        facilities: facilities,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }
}
