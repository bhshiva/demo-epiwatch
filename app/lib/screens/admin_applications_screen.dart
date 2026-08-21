import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/application_models.dart';
import '../state/admin_applications.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Facility onboarding review queue: approve/reject requests from hospitals
/// and clinics. Approval provisions a Facility + Doctor account and shows
/// the one-time password exactly once -- there's no email path yet, so
/// admin relays it out-of-band.
class AdminApplicationsScreen extends ConsumerStatefulWidget {
  final String userName;
  const AdminApplicationsScreen({super.key, required this.userName});

  @override
  ConsumerState<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends ConsumerState<AdminApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.read(adminApplicationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminApplicationsProvider);
    final notifier = ref.read(adminApplicationsProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 18),
              ],
              const Text('Facility Applications',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              MutedText('Logged-in: ${widget.userName}'),
              const SizedBox(height: 22),
              if (state.lastApproval != null) ...[
                _ApprovalCredentialCard(
                  result: state.lastApproval!,
                  onDismiss: notifier.dismissLastApproval,
                ),
                const SizedBox(height: 18),
              ],
              SectionCard(child: _ApplicationsBody(state: state, notifier: notifier)),
            ],
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

class _ApprovalCredentialCard extends StatelessWidget {
  final ApplicationApproveResult result;
  final VoidCallback onDismiss;
  const _ApprovalCredentialCard({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) => SectionCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: AppColors.accentGreen, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Approved -- shown once',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const MutedText(
                'Relay this password to the applicant yourself -- there is no email path yet. '
                'It will not be shown again; they must change it on first login.'),
            const SizedBox(height: 12),
            _CredentialRow(label: 'Email', value: result.email),
            _CredentialRow(label: 'Temporary password', value: result.temporaryPassword),
          ],
        ),
      );
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
            Expanded(
              child: SelectableText(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
}

class _ApplicationsBody extends StatelessWidget {
  final AdminApplicationsState state;
  final AdminApplicationsNotifier notifier;
  const _ApplicationsBody({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.isBusy && state.applications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final pending = state.pending;
    if (pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(child: MutedText('No applications awaiting review.')),
      );
    }
    return Column(
      children: [
        for (final application in pending)
          _ApplicationRow(
            key: ValueKey(application.applicationId),
            application: application,
            busy: state.isBusy,
            onApprove: () => notifier.approve(application.applicationId),
            onReject: (reason) => notifier.reject(application.applicationId, reason),
          ),
      ],
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  final FacilityApplication application;
  final bool busy;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const _ApplicationRow({
    super.key,
    required this.application,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  Future<void> _promptReject(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) onReject(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(application.facilityName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          MutedText(
              '${application.facilityType} · ${application.district}, ${application.state} '
              '· requesting ${application.requestedRole} access'),
          const SizedBox(height: 4),
          MutedText('${application.contactName} · ${application.contactEmail}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : () => _promptReject(context),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
