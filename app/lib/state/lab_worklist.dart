import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class LabWorklistState {
  final List<Isolate> pending;
  final bool isBusy;
  final String? error;

  const LabWorklistState({
    this.pending = const [],
    this.isBusy = false,
    this.error,
  });

  LabWorklistState copyWith({
    List<Isolate>? pending,
    bool? isBusy,
    String? error,
  }) =>
      LabWorklistState(
        pending: pending ?? this.pending,
        isBusy: isBusy ?? this.isBusy,
        error: error,
      );
}

final labWorklistProvider =
    NotifierProvider<LabWorklistNotifier, LabWorklistState>(LabWorklistNotifier.new);

class LabWorklistNotifier extends Notifier<LabWorklistState> {
  @override
  LabWorklistState build() => const LabWorklistState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      final rows = await api.getWorklist();
      state = LabWorklistState(pending: rows);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }
}
