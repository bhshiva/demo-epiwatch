import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_models.dart';
import '../services/app_strings.dart';
import '../services/pdf_export.dart';
import '../state/locale.dart';
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
  ConsumerState<PatientRecordsScreen> createState() =>
      _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends ConsumerState<PatientRecordsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(patientRecordsProvider.notifier).search();
      }
    });
  }

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
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(isPhone ? 16 : 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('patient_records', ref.watch(localeProvider)),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            MutedText(
              AppStrings.get('patient_records_sub', ref.watch(localeProvider)),
            ),
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
                          decoration: InputDecoration(
                            hintText: AppStrings.get(
                              'search_patients_placeholder',
                              ref.watch(localeProvider),
                            ),
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
                        child: Text(
                          AppStrings.get('search', ref.watch(localeProvider)),
                        ),
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
                        SizedBox(
                          height: 320,
                          child: _ResultsPanel(state: state),
                        ),
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
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.searchError != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        state.searchError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.statusCritical,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                if (!state.hasSearched) {
                  return const Center(
                    child: MutedText(
                      'Type a name, ABHA id, phone or MRN to search.',
                    ),
                  );
                }
                if (!state.isSearching && state.results.isEmpty) {
                  return const Center(child: MutedText('No patients found.'));
                }
                return ListView.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final p = state.results[index];
                    final isSelected =
                        state.selectedPatient?.patientId == p.patientId;
                    return _PatientResultTile(
                      patient: p,
                      isSelected: isSelected,
                      onTap: () => ref
                          .read(patientRecordsProvider.notifier)
                          .selectPatient(p),
                    );
                  },
                );
              },
            ),
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
                color: isSelected ? AppColors.accentMint : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      MutedText(patient.summary),
                      if (patient.abhaId != null &&
                          patient.abhaId!.isNotEmpty) ...[
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
            Text(
              patient.fullName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: 2),
            MutedText(patient.summary),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Builder(
              builder: (context) {
                if (patient == null) {
                  return const Center(
                    child: MutedText('Select a patient to view their history.'),
                  );
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
                        style: const TextStyle(
                          color: AppColors.statusCritical,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                if (state.history.isEmpty) {
                  return const Center(
                    child: MutedText('No previous visits on file.'),
                  );
                }
                return ListView.builder(
                  itemCount: state.history.length,
                  itemBuilder: (context, index) => _HistoryEntryTile(
                    patient: patient,
                    entry: state.history[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final PatientSearchResult patient;
  final PatientHistoryEntry entry;
  const _HistoryEntryTile({required this.patient, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showDialog(
          context: context,
          builder: (context) =>
              _ReportDetailsDialog(patient: patient, entry: entry),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                        Text(
                          entry.reportDate,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.diagnosis ?? '—',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.complaints != null &&
                        entry.complaints!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      MutedText(entry.complaints!),
                    ],
                    if (entry.hasLabResult) ...[
                      const SizedBox(height: 4),
                      MutedText(
                        [
                          if (entry.pathogen != null &&
                              entry.pathogen!.isNotEmpty)
                            entry.pathogen,
                          if (entry.cultureResult != null &&
                              entry.cultureResult!.isNotEmpty)
                            entry.cultureResult,
                          if (entry.astResult != null &&
                              entry.astResult!.isNotEmpty)
                            'AST: ${entry.astResult}',
                        ].whereType<String>().join(' · '),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (entry.diagnosisStatus != null &&
                  entry.diagnosisStatus!.isNotEmpty)
                StatusChip(label: entry.diagnosisStatus!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetailsDialog extends ConsumerStatefulWidget {
  final PatientSearchResult patient;
  final PatientHistoryEntry entry;

  const _ReportDetailsDialog({required this.patient, required this.entry});

  @override
  ConsumerState<_ReportDetailsDialog> createState() => _ReportDetailsDialogState();
}

class _ReportDetailsDialogState extends ConsumerState<_ReportDetailsDialog> {
  bool _isExporting = false;

  Future<void> _downloadPdf() async {
    setState(() => _isExporting = true);
    try {
      await PdfExportService.exportReportPdf(
        patient: widget.patient,
        entry: widget.entry,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final patient = widget.patient;
    final entry = widget.entry;
    final reportIdShort = entry.reportId.length > 8
        ? entry.reportId.substring(0, 8)
        : entry.reportId;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web Header with Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppColors.accentTeal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('clinical_visit_report', lang),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.get("visit_date", lang)}: ${entry.reportDate}  •  ${AppStrings.get("report_id", lang)}: #$reportIdShort',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.diagnosisStatus != null &&
                      entry.diagnosisStatus!.isNotEmpty) ...[
                    StatusChip(label: entry.diagnosisStatus!),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: AppStrings.get('close', lang),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 20),

              // Patient Summary Web Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), // Refreshing teal-mint tint
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.accentTeal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.get('patient_information', lang).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentTeal,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((patient.facilityMrn != null &&
                            patient.facilityMrn!.isNotEmpty) ||
                        (patient.abhaId != null &&
                            patient.abhaId!.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (patient.facilityMrn != null &&
                              patient.facilityMrn!.isNotEmpty)
                            Text(
                              'MRN: ${patient.facilityMrn}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (patient.facilityMrn != null &&
                              patient.facilityMrn!.isNotEmpty &&
                              patient.abhaId != null &&
                              patient.abhaId!.isNotEmpty)
                            const Text(
                              '  •  ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (patient.abhaId != null &&
                              patient.abhaId!.isNotEmpty)
                            Text(
                              'ABHA ID: ${patient.abhaId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Clinical Findings Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('clinical_findings', lang),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: AppStrings.get('diagnosis_label', lang),
                      value: entry.diagnosis ?? '—',
                    ),
                    _DetailRow(
                      label: AppStrings.get('chief_complaints', lang),
                      value: entry.complaints ?? '—',
                    ),
                  ],
                ),
              ),

              // Lab & AMR Section (if present)
              if (entry.hasLabResult) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('lab_results', lang),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entry.pathogen != null && entry.pathogen!.isNotEmpty)
                        _DetailRow(
                          label: AppStrings.get('identified_pathogen', lang),
                          value: entry.pathogen!,
                        ),
                      if (entry.cultureResult != null &&
                          entry.cultureResult!.isNotEmpty)
                        _DetailRow(
                          label: AppStrings.get('culture_result_label', lang),
                          value: entry.cultureResult!,
                        ),
                      if (entry.astResult != null &&
                          entry.astResult!.isNotEmpty)
                        _DetailRow(
                          label: AppStrings.get('ast_susceptibility', lang),
                          value: entry.astResult!,
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 20),

              // Web Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(AppStrings.get('close', lang)),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    onPressed: _isExporting ? null : _downloadPdf,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                     label: Text(
                      _isExporting
                          ? AppStrings.get('generating_pdf', lang)
                          : AppStrings.get('download_pdf', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
