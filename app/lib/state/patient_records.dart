import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

/// State for the Patient Records screen: a search box over patients, and the
/// visit history of whichever patient is currently selected.
///
/// Search and history-load errors are kept distinct (`searchError` vs
/// `historyError`) and each carries whether it came from a server refusal
/// (`ApiException`) or a transport failure (`NetworkException`) via
/// [isNetworkError] / [isHistoryNetworkError], since the two will need
/// different treatment once offline support lands (a refusal is final; a
/// network failure is retryable).
class PatientRecordsState {
  final String query;
  final bool isSearching;
  final List<PatientSearchResult> results;
  final String? searchError;
  final bool isSearchNetworkError;

  final PatientSearchResult? selectedPatient;
  final bool isLoadingHistory;
  final List<PatientHistoryEntry> history;
  final String? historyError;
  final bool isHistoryNetworkError;

  const PatientRecordsState({
    this.query = '',
    this.isSearching = false,
    this.results = const [],
    this.searchError,
    this.isSearchNetworkError = false,
    this.selectedPatient,
    this.isLoadingHistory = false,
    this.history = const [],
    this.historyError,
    this.isHistoryNetworkError = false,
  });

  bool get hasSearched => query.trim().isNotEmpty;

  PatientRecordsState copyWith({
    String? query,
    bool? isSearching,
    List<PatientSearchResult>? results,
    String? searchError,
    bool clearSearchError = false,
    bool? isSearchNetworkError,
    PatientSearchResult? selectedPatient,
    bool clearSelectedPatient = false,
    bool? isLoadingHistory,
    List<PatientHistoryEntry>? history,
    String? historyError,
    bool clearHistoryError = false,
    bool? isHistoryNetworkError,
  }) =>
      PatientRecordsState(
        query: query ?? this.query,
        isSearching: isSearching ?? this.isSearching,
        results: results ?? this.results,
        searchError: clearSearchError ? null : (searchError ?? this.searchError),
        isSearchNetworkError: isSearchNetworkError ?? this.isSearchNetworkError,
        selectedPatient:
            clearSelectedPatient ? null : (selectedPatient ?? this.selectedPatient),
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        history: history ?? this.history,
        historyError: clearHistoryError ? null : (historyError ?? this.historyError),
        isHistoryNetworkError: isHistoryNetworkError ?? this.isHistoryNetworkError,
      );
}

final patientRecordsProvider =
    NotifierProvider<PatientRecordsNotifier, PatientRecordsState>(
        PatientRecordsNotifier.new);

class PatientRecordsNotifier extends Notifier<PatientRecordsState> {
  @override
  PatientRecordsState build() => const PatientRecordsState();

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  Future<void> search() async {
    final term = state.query.trim();
    if (term.isEmpty) {
      state = state.copyWith(results: const [], clearSearchError: true);
      return;
    }

    state = state.copyWith(isSearching: true, clearSearchError: true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await api.searchPatients(term);
      state = state.copyWith(isSearching: false, results: results, clearSearchError: true);
    } on ApiException catch (e) {
      state = state.copyWith(
          isSearching: false, results: const [], searchError: e.message, isSearchNetworkError: false);
    } on NetworkException catch (e) {
      state = state.copyWith(
          isSearching: false, results: const [], searchError: e.message, isSearchNetworkError: true);
    }
  }

  Future<void> selectPatient(PatientSearchResult patient) async {
    state = state.copyWith(
      selectedPatient: patient,
      isLoadingHistory: true,
      history: const [],
      clearHistoryError: true,
    );
    final api = ref.read(apiClientProvider);
    try {
      final history = await api.patientHistory(patient.patientId);
      state = state.copyWith(isLoadingHistory: false, history: history, clearHistoryError: true);
    } on ApiException catch (e) {
      state = state.copyWith(
          isLoadingHistory: false, historyError: e.message, isHistoryNetworkError: false);
    } on NetworkException catch (e) {
      state = state.copyWith(
          isLoadingHistory: false, historyError: e.message, isHistoryNetworkError: true);
    }
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedPatient: true,
      history: const [],
      clearHistoryError: true,
      isLoadingHistory: false,
    );
  }
}
