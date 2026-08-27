import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/session.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'state/auth.dart';
import 'theme/app_theme.dart';
import 'workspaces.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Fallback gracefully if .env asset is missing
  }
  runApp(const ProviderScope(child: EpiWatchApp()));
}

class EpiWatchApp extends ConsumerWidget {
  const EpiWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).session;

    return MaterialApp(
      title: 'EpiWatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: switch (session) {
        null => const LoginScreen(),
        // An admin-provisioned account starts on a generated one-time
        // password (see routers/applications.py) and can't reach the rest
        // of the app until it sets its own.
        Session(mustChangePassword: true) => const ChangePasswordScreen(),
        _ => workspaceFor(session),
      },
    );
  }
}
