import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_models.dart';
import '../state/patient_records.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

/// Patient Records screen: search for a patient, then drill into their visit
/// history.
///
/// The WPF client's `PatientRecordsView` put its `DataGrid` inside an
/// unbounded `ScrollViewer`, which disabled the grid's row virtualization and
/// produced a 5-10s render delay on large result sets (see
/// swasthya_sentinel_open_items.md / the commit that fixed the equivalent bug
/// in Patient Records loading). Here both the results list and the history
/// list live inside `Expanded` + `ListView.builder`, each within a
/// fixed-height card area, so nothing lays out inside an unbounded scroll
/// region and this class of bug cannot recur.
class PatientRecordsScreen extends ConsumerStatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  ConsumerState<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends ConsumerState<PatientRecordsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(patientRecordsProvider.notifier).setQuery(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(patientRecordsProvider.notifier).search();
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    ref.read(patientRecordsProvider.notifier).search();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientRecordsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Records',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 7),
            const MutedText(
                'Search patients by name, ABHA number, phone or facility MRN, then review their visit history.'),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Search patients...',
                            isDense: true,
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _onSubmitted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {
                          _debounce?.cancel();
                          ref.read(patientRecordsProvider.notifier).search();
                        },
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: _ResultsPanel(state: state)),
                        const SizedBox(width: 18),
                        Expanded(flex: 3, child: _HistoryPanel(state: state)),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 320, child: _ResultsPanel(state: state)),
                        const SizedBox(height: 18),
                        Expanded(child: _HistoryPanel(state: state)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsPanel extends ConsumerWidget {
  final PatientRecordsState state;
  const _ResultsPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle('Results')),
              if (state.isSearching)
                const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Builder(builder: (context) {
              if (state.searchError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      state.searchError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.statusCritical, fontSize: 13),
                    ),
                  ),
                );
              }
              if (!state.hasSearched) {
                return const Center(child: MutedText('Type a name, ABHA id, phone or MRN to search.'));
              }
              if (!state.isSearching && state.results.isEmpty) {
                return const Center(child: MutedText('No patients found.'));
              }
              return ListView.builder(
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final p = state.results[index];
                  final isSelected = state.selectedPatient?.patientId == p.patientId;
                  return _PatientResultTile(
                    patient: p,
                    isSelected: isSelected,
                    onTap: () => ref.read(patientRecordsProvider.notifier).selectPatient(p),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PatientResultTile extends StatelessWidget {
  final PatientSearchResult patient;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientResultTile({
    required this.patient,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0xFFDCEFE4) : AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isSelected ? AppColors.accentMint : AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      MutedText(patient.summary),
                      if (patient.abhaId != null && patient.abhaId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        MutedText('ABHA: ${patient.abhaId}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MutedText(patient.visitSummary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final PatientRecordsState state;
  const _HistoryPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final patient = state.selectedPatient;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Visit History'),
          const SizedBox(height: 4),
          if (patient != null) ...[
            Text(patient.fullName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentGreen)),
            const SizedBox(height: 2),
            MutedText(patient.summary),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Builder(builder: (context) {
              if (patient == null) {
                return const Center(child: MutedText('Select a patient to view their history.'));
              }
              if (state.isLoadingHistory) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.historyError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      state.historyError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.statusCritical, fontSize: 13),
                    ),
                  ),
                );
              }
              if (state.history.isEmpty) {
                return const Center(child: MutedText('No previous visits on file.'));
              }
              return ListView.builder(
                itemCount: state.history.length,
                itemBuilder: (context, index) => _HistoryEntryTile(entry: state.history[index]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final PatientHistoryEntry entry;
  const _HistoryEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.reportDate,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(entry.diagnosis ?? '—',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                if (entry.complaints != null && entry.complaints!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  MutedText(entry.complaints!),
                ],
                if (entry.hasLabResult) ...[
                  const SizedBox(height: 4),
                  MutedText(
                    [
                      if (entry.pathogen != null && entry.pathogen!.isNotEmpty) entry.pathogen,
                      if (entry.cultureResult != null && entry.cultureResult!.isNotEmpty)
                        entry.cultureResult,
                      if (entry.astResult != null && entry.astResult!.isNotEmpty)
                        'AST: ${entry.astResult}',
                    ].whereType<String>().join(' · '),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.diagnosisStatus != null && entry.diagnosisStatus!.isNotEmpty)
            StatusChip(label: entry.diagnosisStatus!),
        ],
      ),
    );
  }
}
