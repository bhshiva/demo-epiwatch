import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/application_models.dart';
import '../services/api_exceptions.dart';
import 'auth.dart';

class AdminApplicationsState {
  final List<FacilityApplication> applications;
  final bool isBusy;
  final String? error;
  // Set right after an approval, so the screen can show the one-time
  // password once. Cleared on the next load/dismiss -- never persisted.
  final ApplicationApproveResult? lastApproval;

  const AdminApplicationsState({
    this.applications = const [],
    this.isBusy = false,
    this.error,
    this.lastApproval,
  });

  AdminApplicationsState copyWith({
    List<FacilityApplication>? applications,
    bool? isBusy,
    String? error,
    ApplicationApproveResult? lastApproval,
    bool clearLastApproval = false,
  }) =>
      AdminApplicationsState(
        applications: applications ?? this.applications,
        isBusy: isBusy ?? this.isBusy,
        error: error,
        lastApproval: clearLastApproval ? null : (lastApproval ?? this.lastApproval),
      );

  List<FacilityApplication> get pending =>
      applications.where((a) => a.status == 'pending').toList();
}

final adminApplicationsProvider =
    NotifierProvider<AdminApplicationsNotifier, AdminApplicationsState>(
        AdminApplicationsNotifier.new);

class AdminApplicationsNotifier extends Notifier<AdminApplicationsState> {
  @override
  AdminApplicationsState build() => const AdminApplicationsState();

  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      final applications = await api.getApplications();
      state = state.copyWith(applications: applications, isBusy: false);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  Future<void> approve(String applicationId) async {
    state = state.copyWith(isBusy: true, error: null, clearLastApproval: true);
    final api = ref.read(apiClientProvider);
    try {
      final result = await api.approveApplication(applicationId);
      state = state.copyWith(isBusy: false, lastApproval: result);
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  Future<void> reject(String applicationId, String reason) async {
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      await api.rejectApplication(applicationId, reason);
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  void dismissLastApproval() => state = state.copyWith(clearLastApproval: true);
}
