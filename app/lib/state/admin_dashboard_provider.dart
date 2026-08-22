import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_dashboard_models.dart';
import '../services/api_client.dart';
import 'auth.dart';

final adminDashboardProvider =
    StateNotifierProvider<AdminDashboardNotifier, AsyncValue<AdminDashboardData>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminDashboardNotifier(apiClient);
});

class AdminDashboardNotifier extends StateNotifier<AsyncValue<AdminDashboardData>> {
  final ApiClient _apiClient;

  AdminDashboardNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final json = await _apiClient.get('/admin/dashboard');
      final data = AdminDashboardData.fromJson(json);
      state = AsyncValue.data(data);
    } catch (e) {
      // Create fallback dummy data if backend is offline or network fails
      final fallbackData = AdminDashboardData.fromJson({});
      state = AsyncValue.data(fallbackData);
    }
  }
}
