import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surveillance_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class DiagnosisTrend {
  final String diagnosis;
  final int last7d;
  final int prior7d;
  final int last30d;
  final int prior30d;

  const DiagnosisTrend({
    required this.diagnosis,
    required this.last7d,
    required this.prior7d,
    required this.last30d,
    required this.prior30d,
  });

  double? get delta7dPercent => prior7d == 0 ? null : (last7d - prior7d) / prior7d * 100;
  double? get delta30dPercent => prior30d == 0 ? null : (last30d - prior30d) / prior30d * 100;

  /// A plain threshold on real week-over-week change, not a statistical
  /// anomaly test -- deliberately not called a "signal" or given a
  /// confidence score, unlike the illustrative demo alerts elsewhere in
  /// this workspace. See ML_PLAN.md for what a real detector would need.
  String get trendLabel {
    final d = delta7dPercent;
    if (d == null) return 'New';
    if (d >= 10) return 'Rising';
    if (d <= -10) return 'Falling';
    return 'Stable';
  }
}

class DiseaseTrendsState {
  final List<DiseaseDailyPoint> raw;
  final bool isBusy;
  final String? error;
  final String? diagnosisFilter;

  const DiseaseTrendsState({
    this.raw = const [],
    this.isBusy = false,
    this.error,
    this.diagnosisFilter,
  });

  DiseaseTrendsState copyWith({
    List<DiseaseDailyPoint>? raw,
    bool? isBusy,
    String? error,
    String? diagnosisFilter,
    bool clearFilter = false,
  }) =>
      DiseaseTrendsState(
        raw: raw ?? this.raw,
        isBusy: isBusy ?? this.isBusy,
        error: error,
        diagnosisFilter: clearFilter ? null : (diagnosisFilter ?? this.diagnosisFilter),
      );

  List<String> get availableDiagnoses => raw.map((p) => p.diagnosis).toSet().toList()..sort();

  List<DiseaseDailyPoint> get filtered =>
      diagnosisFilter == null ? raw : raw.where((p) => p.diagnosis == diagnosisFilter).toList();

  /// Real day-by-day case counts per diagnosis, for the multi-line chart.
  Map<String, Map<String, int>> get seriesByDiagnosis {
    final result = <String, Map<String, int>>{};
    for (final point in filtered) {
      result.putIfAbsent(point.diagnosis, () => {})[point.reportDate] = point.caseCount;
    }
    return result;
  }

  List<DiagnosisTrend> get trends {
    final today = DateTime.now();
    final byDiagnosis = <String, List<DiseaseDailyPoint>>{};
    for (final point in raw) {
      byDiagnosis.putIfAbsent(point.diagnosis, () => []).add(point);
    }

    int sumInRange(List<DiseaseDailyPoint> points, int daysAgoStart, int daysAgoEnd) {
      var total = 0;
      for (final p in points) {
        final date = DateTime.tryParse(p.reportDate);
        if (date == null) continue;
        final age = today.difference(date).inDays;
        if (age >= daysAgoEnd && age < daysAgoStart) total += p.caseCount;
      }
      return total;
    }

    final trends = <DiagnosisTrend>[];
    for (final entry in byDiagnosis.entries) {
      trends.add(DiagnosisTrend(
        diagnosis: entry.key,
        last7d: sumInRange(entry.value, 7, 0),
        prior7d: sumInRange(entry.value, 14, 7),
        last30d: sumInRange(entry.value, 30, 0),
        prior30d: sumInRange(entry.value, 60, 30),
      ));
    }
    trends.sort((a, b) => b.last30d.compareTo(a.last30d));
    return trends;
  }
}

final diseaseTrendsProvider =
    NotifierProvider<DiseaseTrendsNotifier, DiseaseTrendsState>(DiseaseTrendsNotifier.new);

class DiseaseTrendsNotifier extends Notifier<DiseaseTrendsState> {
  @override
  DiseaseTrendsState build() => const DiseaseTrendsState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      // 60 days: enough to compute both a 7d-over-7d and a 30d-over-30d
      // real delta from one fetch.
      final raw = await api.getDiseaseDaily(days: 60);
      state = state.copyWith(raw: raw, isBusy: false);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  void setDiagnosisFilter(String? diagnosis) {
    if (diagnosis == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(diagnosisFilter: diagnosis);
    }
  }
}
