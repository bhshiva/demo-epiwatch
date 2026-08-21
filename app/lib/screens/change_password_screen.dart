import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth.dart';
import '../theme/app_colors.dart';

/// Forced when session.mustChangePassword is true -- an admin-provisioned
/// account (see routers/applications.py) starts on a generated one-time
/// password and cannot reach the rest of the app until it sets its own.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  void _submit() {
    if (_next.text.trim().length < 8) return;
    ref.read(authProvider.notifier).changePassword(_current.text, _next.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Set a new password',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account was created with a temporary password. Choose your own before continuing.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _current,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Temporary password'),
                      autofillHints: const [AutofillHints.password],
                      enabled: !auth.isBusy,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _next,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password (min. 8 characters)',
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                        ),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      enabled: !auth.isBusy,
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: auth.error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _submit,
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Set password'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.isBusy ? null : () => ref.read(authProvider.notifier).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.statusCritical.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.statusCritical.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.statusCritical, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.statusCritical, fontSize: 13))),
        ]),
      );
}
