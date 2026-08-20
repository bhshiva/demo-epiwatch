import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

/// One bar in the pathogen-frequency chart.
class PathogenCount {
  final String pathogen;
  final int count;
  const PathogenCount(this.pathogen, this.count);
}

/// One stacked bar in the S/I/R chart, per antibiotic.
class SirCount {
  final String antibiotic;
  final int susceptible;
  final int intermediate;
  final int resistant;
  final int notTested;

  const SirCount({
    required this.antibiotic,
    this.susceptible = 0,
    this.intermediate = 0,
    this.resistant = 0,
    this.notTested = 0,
  });

  int get total => susceptible + intermediate + resistant + notTested;
}

/// Counts isolates by named pathogen, most frequent first, top 8 — mirrors
/// `LabDashboardViewModel.BuildPathogenChart` in the WPF client.
List<PathogenCount> pathogenCounts(List<Isolate> isolates) {
  final counts = <String, int>{};
  for (final iso in isolates) {
    final p = iso.pathogen;
    if (p == null || p.trim().isEmpty) continue;
    counts[p] = (counts[p] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(8).map((e) => PathogenCount(e.key, e.value)).toList();
}

/// Aggregates S/I/R (and not-tested) counts per antibiotic across all
/// isolates' AST panels, most-tested first, top 8 — mirrors
/// `LabDashboardViewModel.BuildSusceptibilityChart`.
List<SirCount> sirCounts(List<Isolate> isolates) {
  final susceptible = <String, int>{};
  final intermediate = <String, int>{};
  final resistant = <String, int>{};
  final notTested = <String, int>{};
  final drugs = <String>{};

  for (final iso in isolates) {
    for (final ast in iso.astResults) {
      final drug = ast.antibiotic;
      drugs.add(drug);
      switch (ast.astResult) {
        case 'Susceptible':
          susceptible[drug] = (susceptible[drug] ?? 0) + 1;
          break;
        case 'Intermediate':
          intermediate[drug] = (intermediate[drug] ?? 0) + 1;
          break;
        case 'Resistant':
          resistant[drug] = (resistant[drug] ?? 0) + 1;
          break;
        case 'Not tested':
          notTested[drug] = (notTested[drug] ?? 0) + 1;
          break;
      }
    }
  }

  final rows = drugs
      .map((drug) => SirCount(
            antibiotic: drug,
            susceptible: susceptible[drug] ?? 0,
            intermediate: intermediate[drug] ?? 0,
            resistant: resistant[drug] ?? 0,
            notTested: notTested[drug] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return rows.take(8).toList();
}

class LabDashboardState {
  final LabSummary summary;
  final List<PathogenCount> pathogens;
  final List<SirCount> sir;
  final bool isBusy;
  final String? error;

  const LabDashboardState({
    this.summary = LabSummary.zero,
    this.pathogens = const [],
    this.sir = const [],
    this.isBusy = false,
    this.error,
  });

  LabDashboardState copyWith({
    LabSummary? summary,
    List<PathogenCount>? pathogens,
    List<SirCount>? sir,
    bool? isBusy,
    String? error,
  }) =>
      LabDashboardState(
        summary: summary ?? this.summary,
        pathogens: pathogens ?? this.pathogens,
        sir: sir ?? this.sir,
        isBusy: isBusy ?? this.isBusy,
        error: error,
      );
}

final labDashboardProvider =
    NotifierProvider<LabDashboardNotifier, LabDashboardState>(LabDashboardNotifier.new);

class LabDashboardNotifier extends Notifier<LabDashboardState> {
  @override
  LabDashboardState build() => const LabDashboardState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      final summary = await api.getLabSummary();
      final isolates = await api.getIsolates();
      state = LabDashboardState(
        summary: summary,
        pathogens: pathogenCounts(isolates),
        sir: sirCounts(isolates),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }
}
