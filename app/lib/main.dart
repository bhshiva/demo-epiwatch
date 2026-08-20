import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'state/auth.dart';
import 'theme/app_theme.dart';
import 'workspaces.dart';

void main() {
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
      home: session == null ? const LoginScreen() : workspaceFor(session),
    );
  }
}
