import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_models.dart';
import '../state/lab_worklist.dart';
import '../state/submit_isolate.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';
import 'shell_screen.dart';

/// Cultures still awaiting a final result, oldest first (server-sorted).
class LabWorklistScreen extends ConsumerStatefulWidget {
  const LabWorklistScreen({super.key});

  @override
  ConsumerState<LabWorklistScreen> createState() => _LabWorklistScreenState();
}

class _LabWorklistScreenState extends ConsumerState<LabWorklistScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: load mutates provider state, which must not happen during
    // this widget's own build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.read(labWorklistProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labWorklistProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(labWorklistProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text('Culture Worklist',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.read(labWorklistProvider.notifier).load(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MutedText(_summaryText(state)),
              const SizedBox(height: 18),
              SectionCard(child: _WorklistBody(state: state, onOpen: _openIsolate)),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryText(LabWorklistState state) {
    if (state.isBusy) return 'Loading…';
    if (state.pending.isEmpty) return 'Nothing awaiting a final result';
    final n = state.pending.length;
    return '$n awaiting a final result';
  }

  /// Prefills the Culture & AST form from this worklist entry and switches
  /// to that tab so the technician can finish/correct it there.
  void _openIsolate(Isolate isolate) {
    ref.read(submitIsolateProvider.notifier).loadForEdit(isolate);
    ShellNav.of(context).navigateTo('submit-isolate');
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

class _WorklistBody extends StatelessWidget {
  final LabWorklistState state;
  final ValueChanged<Isolate> onOpen;
  const _WorklistBody({required this.state, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (state.isBusy && state.pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: MutedText('No isolates awaiting results.'),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 36,
        headingTextStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        columns: const [
          DataColumn(label: Text('ACCESSION NO')),
          DataColumn(label: Text('COLLECTION DATE')),
          DataColumn(label: Text('SPECIMEN')),
          DataColumn(label: Text('CULTURE RESULT')),
          DataColumn(label: Text('PATHOGEN')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final iso in state.pending)
            DataRow(
              cells: [
                DataCell(Text(iso.accessionNo ?? '—')),
                DataCell(Text(iso.collectionDate ?? '—')),
                DataCell(Text(iso.specimenType ?? '—')),
                DataCell(Text(iso.cultureResult ?? '—')),
                DataCell(Text(iso.pathogen ?? '—')),
                DataCell(StatusChip(label: iso.status)),
                DataCell(TextButton(
                  onPressed: () => onOpen(iso),
                  child: const Text('Finish'),
                )),
              ],
            ),
        ],
      ),
    );
  }
}
