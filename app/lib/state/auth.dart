import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthState {
  final Session? session;
  final bool isBusy;
  final String? error;

  const AuthState({this.session, this.isBusy = false, this.error});

  bool get isSignedIn => session != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Enter your email and password.');
      return;
    }

    state = const AuthState(isBusy: true);
    final api = ref.read(apiClientProvider);
    try {
      final session = await api.login(email.trim(), password);
      api.setToken(session.accessToken);
      state = AuthState(session: session);
    } on ApiException catch (e) {
      // 401 here means bad credentials, not an expired session.
      final message =
          e.statusCode == 401 ? 'Incorrect email or password.' : e.message;
      state = AuthState(error: message);
    } on NetworkException catch (e) {
      state = AuthState(error: e.message);
    }
  }

  void signOut() {
    ref.read(apiClientProvider).setToken(null);
    state = const AuthState();
  }
}
