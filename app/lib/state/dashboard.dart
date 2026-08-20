import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class DashboardState {
  final DashboardSummary summary;
  final List<ReportSummary> recentReports;
  final bool isBusy;
  final String? error;

  const DashboardState({
    this.summary = DashboardSummary.zero,
    this.recentReports = const [],
    this.isBusy = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardSummary? summary,
    List<ReportSummary>? recentReports,
    bool? isBusy,
    String? error,
  }) =>
      DashboardState(
        summary: summary ?? this.summary,
        recentReports: recentReports ?? this.recentReports,
        isBusy: isBusy ?? this.isBusy,
        error: error,
      );
}

final dashboardProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      final summary = await api.getDashboardSummary();
      final reports = await api.getReports();
      state = DashboardState(summary: summary, recentReports: reports);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }
}
