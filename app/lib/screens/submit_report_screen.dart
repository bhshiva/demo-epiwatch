import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_models.dart';
import '../screens/shell_screen.dart';
import '../services/clinical_catalog.dart';
import '../state/auth.dart';
import '../state/submit_report.dart';
import '../theme/app_colors.dart';
import '../widgets/intelligence_audit_banner.dart';
import '../widgets/ocr_ingestion_card.dart';
import '../widgets/section_card.dart';
import '../services/app_strings.dart';
import '../state/locale.dart';
import '../widgets/status_chip.dart';

/// Submit Report screen: the doctor's clinical-report form, ported from
/// `SubmitReportView.xaml` / `SubmitReportViewModel.cs`.
///
/// The patient-identity / duplicate-matching flow is the most important part
/// of this screen (see the class doc on [SubmitReportState] for the field
/// mapping) — search an existing patient, register a new one with optional
/// ABHA verification, and resolve near-duplicate matches either by reusing an
/// existing record or explicitly confirming "this is a new patient".
class SubmitReportScreen extends ConsumerStatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends ConsumerState<SubmitReportScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    if (state.isSubmitted) {
      return _SuccessView(state: state);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('submit_report', lang),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  MutedText(
                    AppStrings.get('submit_report_sub', lang),
                  ),
                  const SizedBox(height: 20),
                  OcrIngestionCard(
                    documentType: 'clinical_report',
                    apiClient: ref.read(apiClientProvider),
                    onParsed: (result) {
                      notifier.applyOcrResult(result);
                    },
                  ),
                  if (state.intelligenceAudit != null)
                    IntelligenceAuditBanner(
                      audit: state.intelligenceAudit!,
                      onDismiss: notifier.clearIntelligenceAudit,
                    ),
                  const _PatientSection(),
                  const SizedBox(height: 18),
                  const _ClinicalSummarySection(),
                  const SizedBox(height: 18),
                  const _DiagnosisSection(),
                  const SizedBox(height: 18),
                  const _AcornSection(),
                  const SizedBox(height: 18),
                  const _LabSection(),
                  const SizedBox(height: 18),
                  const _PrescriptionsSection(),
                ],
              ),
            ),
          ),
        ),
        _SubmitBar(state: state),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) {
          final lang = ref.watch(localeProvider);
          final keyMap = {
            'Chief Complaint *': 'complaints',
            'Chief Complaints': 'complaints',
            'Medical History': 'medical_history',
            'Full Name *': 'full_name',
            'Full Name': 'full_name',
            'Age (years) *': 'age',
            'District *': 'district',
            'Sex *': 'gender',
            'Male': 'male',
            'Female': 'female',
            'Other': 'other',
            'Search': 'search',
            'Register new patient': 'register_new_patient',
            'Patient Context': 'patient_context',
            'Patient': 'patient',
          };
          final translationKey = keyMap[text] ?? text;
          final translatedText = AppStrings.get(translationKey, lang);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              translatedText,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          );
        },
      );
}

class _SegmentGroup extends ConsumerWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentGroup({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);

    String getLabel(String val) {
      final keyMap = {
        'Suspected': 'status_suspected',
        'Probable': 'status_probable',
        'Confirmed': 'status_confirmed',
        'Unknown': 'cat_unknown',
        'Community-acquired': 'cat_community_acquired',
        'Hospital-acquired': 'cat_hospital_acquired',
        'Healthcare-associated': 'cat_healthcare_associated',
        'Resistant': 'ast_resistant',
        'Susceptible': 'ast_susceptible',
        'Intermediate': 'ast_intermediate',
        'Not tested': 'ast_not_tested',
      };
      final key = keyMap[val] ?? val.toLowerCase().replaceAll(' ', '_');
      final res = AppStrings.get(key, lang);
      return res != key ? res : val;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _SegmentChip(
            label: getLabel(option),
            isSelected: option.toLowerCase() == selected.toLowerCase(),
            onTap: () => onSelect(option),
          ),
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFDCEFE4) : AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.accentTeal : AppColors.border,
            ),
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final lang = ref.watch(localeProvider);
              final keyMap = {
                'Male': 'male',
                'Female': 'female',
                'Other': 'other',
              };
              final translationKey = keyMap[label] ?? label.toLowerCase();
              final translatedText = AppStrings.get(translationKey, lang);

              return Text(
                translatedText,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OtherField extends ConsumerWidget {
  final bool visible;
  final String value;
  final ValueChanged<String> onChanged;

  const _OtherField({
    required this.visible,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            decoration: const InputDecoration(isDense: true),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Consumer(
              builder: (context, ref, _) => MutedText(
                AppStrings.get('please_specify', ref.watch(localeProvider)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Patient section ============

class _PatientSection extends ConsumerStatefulWidget {
  const _PatientSection();

  @override
  ConsumerState<_PatientSection> createState() => _PatientSectionState();
}

class _PatientSectionState extends ConsumerState<_PatientSection> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _mrnController = TextEditingController();
  final _contactController = TextEditingController();
  final _abhaController = TextEditingController();
  final _ageController = TextEditingController();
  final _districtController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _mrnController.dispose();
    _contactController.dispose();
    _abhaController.dispose();
    _ageController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);

    // Keep controllers in sync with state changes (e.g. clearing search/patient,
    // or ABHA verify prefilling name/district).
    _syncController(_searchController, state.patientSearchText);
    _syncController(_ageController, state.patientAge);
    _syncController(_districtController, state.patientDistrict);
    _syncController(_nameController, state.newPatientName);
    _syncController(_mrnController, state.newPatientMrn);
    _syncController(_contactController, state.newPatientContact);
    _syncController(_abhaController, state.newPatientAbha);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Patient'),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 14),
            child: MutedText(
              'Search an existing patient to continue their record, or register a new one. Names are stored separately from surveillance data and never leave this facility.',
            ),
          ),
          if (!state.hasSelectedPatient && !state.isNewPatient) ...[
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                SizedBox(
                  width: 320,

                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setPatientSearchText,
                    onSubmitted: (_) => notifier.searchPatients(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => notifier.searchPatients(),
                  child: state.isSearching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.get('search', ref.watch(localeProvider))),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: MutedText(
                'Search by name, ABHA number, phone number or facility MRN',
              ),
            ),
            if (state.searchMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: MutedText(state.searchMessage!),
              ),
            if (state.searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    for (final p in state.searchResults)
                      _PatientOptionTile(
                        patient: p,
                        onTap: () => notifier.selectPatient(p),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: () {
                  _nameController.text = state.patientSearchText.trim();
                  notifier.startNewPatient();
                },
                child: Text(AppStrings.get('register_new_patient', ref.watch(localeProvider))),
              ),
            ),
          ],
          if (state.hasSelectedPatient) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCEFE4),
                border: Border.all(color: AppColors.accentMint),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.selectedPatient!.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.selectedPatient!.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.selectedPatient!.visitSummary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: notifier.clearPatient,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            if (state.isLoadingHistory)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.patientHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Previous Visits'),
                    for (final entry in state.patientHistory)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 20,
                          children: [
                            SizedBox(
                              width: 320,

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
                                      Text(
                                        entry.diagnosis ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (entry.diagnosisStatus != null &&
                                entry.diagnosisStatus!.isNotEmpty)
                              StatusChip(label: entry.diagnosisStatus!),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (state.isNewPatient) ...[
            Row(
              children: [
                const Expanded(child: _FieldLabel('New Patient')),
                TextButton(
                  onPressed: notifier.clearPatient,
                  child: const Text('Search instead'),
                ),
              ],
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(isDense: true),
              onChanged: notifier.setNewPatientName,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: MutedText('Full name *'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Facility MRN'),
                      TextField(
                        controller: _mrnController,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: notifier.setNewPatientMrn,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Contact Number'),
                      TextField(
                        controller: _contactController,
                        maxLength: 20,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          errorText: !state.isContactValid
                              ? 'Invalid contact number (must be 10 digits)'
                              : null,
                        ),
                        onChanged: notifier.setNewPatientContact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Date of Birth'),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.newPatientDob ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) notifier.setNewPatientDob(picked);
                        },
                        child: Text(
                          state.newPatientDob == null
                              ? 'Select date'
                              : '${state.newPatientDob!.year}-${state.newPatientDob!.month.toString().padLeft(2, '0')}-${state.newPatientDob!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: MutedText('Keeps age correct on return visits'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('ABHA Number'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _abhaController,
                              maxLength: 20,
                              decoration: const InputDecoration(
                                isDense: true,
                                counterText: '',
                              ),
                              onChanged: notifier.setNewPatientAbha,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => notifier.verifyAbha(),
                            child: state.isVerifyingAbha
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verify'),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: MutedText(
                          '14-digit ABDM health ID, if the patient has one',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.hasAbhaResult) _AbhaResultCard(state: state),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton(
                onPressed: () => notifier.checkForDuplicates(),
                child: state.isCheckingDuplicates
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check for existing records'),
              ),
            ),
            if (state.hasNearMatches)
              _NearMatchesCard(state: state, notifier: notifier),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const SectionTitle('Patient Context'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [
              SizedBox(
                width: 320,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Age (years) *'),
                    TextField(
                      controller: _ageController,
                      maxLength: 3,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        errorText: !state.isAgeValid
                            ? 'Invalid age (0–120 years)'
                            : null,
                      ),
                      onChanged: notifier.setPatientAge,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          children: [
                            const TextSpan(text: 'GLASS band: '),
                            TextSpan(
                              text: state.derivedAgeGroup,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 320,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('District *'),
                    Autocomplete<String>(
                      key: ValueKey(state.patientDistrict),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return ClinicalCatalog.districts;
                        }
                        return ClinicalCatalog.districts.where(
                          (d) => d.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      initialValue: TextEditingValue(
                        text: state.patientDistrict,
                      ),
                      onSelected: notifier.setPatientDistrict,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmit) {
                            if (controller.text != state.patientDistrict &&
                                !focusNode.hasFocus) {
                              controller.text = state.patientDistrict;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: notifier.setPatientDistrict,
                            );
                          },
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: MutedText(
                        'Type to search, or enter another district',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 6),
            child: _FieldLabel('Sex *'),
          ),
          _SegmentGroup(
            options: ClinicalCatalog.sexes,
            selected: state.patientSex,
            onSelect: notifier.setPatientSex,
          ),
        ],
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }
}

class _PatientOptionTile extends StatelessWidget {
  final PatientSearchResult patient;
  final VoidCallback onTap;

  const _PatientOptionTile({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
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
                    ],
                  ),
                ),
                MutedText(patient.visitSummary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AbhaResultCard extends StatelessWidget {
  final SubmitReportState state;
  const _AbhaResultCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final result = state.abhaResult!;
    final Color bg;
    final Color border;
    if (result.verified) {
      bg = const Color(0xFFDCEFE4);
      border = AppColors.accentMint;
    } else if (result.isValid) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
    } else {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
    }

    final statusLabel = result.verified
        ? 'Verified with ABDM registry'
        : (result.isValid
              ? 'Format valid, not verified'
              : 'Invalid ABHA number');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (result.verified) ...[
            const SizedBox(height: 8),
            if (result.name != null)
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Registry name: '),
                    TextSpan(
                      text: result.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Date of birth: '),
                  TextSpan(
                    text: result.dateOfBirth ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '   Gender: '),
                  TextSpan(
                    text: result.gender ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: MutedText(
                'Details above have been filled in from the national registry.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearMatchesCard extends StatelessWidget {
  final SubmitReportState state;
  final SubmitReportNotifier notifier;

  const _NearMatchesCard({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This patient may already exist',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choosing an existing record keeps their history together. Creating a new one splits it.',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 12),
          for (final candidate in state.nearMatches)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: 320,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        MutedText(candidate.summary),
                        const SizedBox(height: 2),
                        MutedText(candidate.visitSummary),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                candidate.confidence.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 320,

                              child: MutedText(candidate.matchedOn.join(', ')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => notifier.useExistingPatient(candidate),
                    child: const Text('Use this patient'),
                  ),
                ],
              ),
            ),
          OutlinedButton(
            onPressed: notifier.createAnyway,
            child: const Text(
              'No — this is a different person, create a new record',
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Clinical summary section ============

class _ClinicalSummarySection extends ConsumerStatefulWidget {
  const _ClinicalSummarySection();

  @override
  ConsumerState<_ClinicalSummarySection> createState() =>
      _ClinicalSummarySectionState();
}

class _ClinicalSummarySectionState
    extends ConsumerState<_ClinicalSummarySection> {
  final _complaintsController = TextEditingController();
  final _historyController = TextEditingController();
  final _newSymptomController = TextEditingController();

  @override
  void dispose() {
    _complaintsController.dispose();
    _historyController.dispose();
    _newSymptomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(AppStrings.get('clinical_summary', lang)),
          const SizedBox(height: 16),
          _FieldLabel('${AppStrings.get('complaints', lang)} *'),
          TextField(
            controller: _complaintsController,
            decoration: const InputDecoration(isDense: true),
            onChanged: notifier.setComplaints,
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('syymptoms', lang)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final symptom in ClinicalCatalog.commonSymptoms)
                _SymptomChip(
                  label: symptom,
                  isSelected: state.symptoms.any(
                    (s) => s.toLowerCase() == symptom.toLowerCase(),
                  ),
                  onTap: () => notifier.toggleSymptom(symptom),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSymptomController,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  notifier.addSymptom(_newSymptomController.text);
                  _newSymptomController.clear();
                },
                child: const Text('Add'),
              ),
            ],
          ),
          if (state.symptoms.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 6),
              child: MutedText('Selected symptoms'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final symptom in state.symptoms)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEFE4),
                      border: Border.all(color: AppColors.accentMint),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          symptom,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => notifier.removeSymptom(symptom),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('relevant_medical_history', lang)),
          TextField(
            controller: _historyController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(isDense: true),
            onChanged: notifier.setMedicalHistory,
          ),
        ],
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SymptomChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFDCEFE4) : AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.accentMint : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? AppColors.accentGreen
                  : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Diagnosis section ============

class _DiagnosisSection extends ConsumerStatefulWidget {
  const _DiagnosisSection();

  @override
  ConsumerState<_DiagnosisSection> createState() => _DiagnosisSectionState();
}

class _DiagnosisSectionState extends ConsumerState<_DiagnosisSection> {
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(AppStrings.get('diagnosis', lang)),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('working_diagnosis', lang)),
          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(isDense: true),
            onChanged: notifier.setDiagnosis,
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('diagnosis_certainty', lang)),
          _SegmentGroup(
            options: ClinicalCatalog.diagnosisStatuses,
            selected: state.diagnosisStatus,
            onSelect: notifier.setDiagnosisStatus,
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('treatment_provided', lang)),
          TextField(
            controller: _treatmentController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(isDense: true),
            onChanged: notifier.setTreatment,
          ),
        ],
      ),
    );
  }
}

// ============ ACORN section ============

class _AcornSection extends ConsumerStatefulWidget {
  const _AcornSection();

  @override
  ConsumerState<_AcornSection> createState() => _AcornSectionState();
}

class _AcornSectionState extends ConsumerState<_AcornSection> {
  final _syndromeOtherController = TextEditingController();
  final _outcomeOtherController = TextEditingController();

  @override
  void dispose() {
    _syndromeOtherController.dispose();
    _outcomeOtherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(AppStrings.get('clinical_context', lang)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: MutedText(
              AppStrings.get('acorn_description', lang),
            ),
          ),
          _FieldLabel(AppStrings.get('infection_syndrome', lang)),
          _Dropdown(
            options: ClinicalCatalog.infectionSyndromes,
            value: state.infectionSyndrome,
            onChanged: notifier.setInfectionSyndrome,
          ),
          _OtherField(
            visible: state.showInfectionSyndromeOther,
            value: state.infectionSyndromeOther,
            onChanged: notifier.setInfectionSyndromeOther,
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.get('infection_origin', lang)),
          _SegmentGroup(
            options: ClinicalCatalog.infectionOrigins,
            selected: state.infectionOrigin,
            onSelect: notifier.setInfectionOrigin,
          ),
          const SizedBox(height: 10),
          _FieldLabel(AppStrings.get('outcome', lang)),
          _Dropdown(
            options: ClinicalCatalog.patientOutcomes,
            value: state.patientOutcome,
            onChanged: notifier.setPatientOutcome,
          ),
          _OtherField(
            visible: state.showPatientOutcomeOther,
            value: state.patientOutcomeOther,
            onChanged: notifier.setPatientOutcomeOther,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: MutedText(
              AppStrings.get('acorn_outcome_note', lang),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends ConsumerWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final items = {...options, if (value.isNotEmpty) value}.toList();

    String getLabel(String val) {
      final keyMap = {
        'Community-acquired': 'cat_community_acquired',
        'Hospital-acquired': 'cat_hospital_acquired',
        'Healthcare-associated': 'cat_healthcare_associated',
        'Unknown': 'cat_unknown',
        'Not yet known': 'cat_not_yet_known',
        'Recovered / Improving': 'cat_recovered_improving',
        'Referred / Transferred': 'cat_referred_transferred',
        'Admitted - under treatment': 'cat_admitted_under_treatment',
        'Died': 'cat_died',
        'Lost to follow-up': 'cat_lost_to_follow_up',
        'Other': 'other',
      };
      final key = keyMap[val] ?? val.toLowerCase().replaceAll(' ', '_');
      final res = AppStrings.get(key, lang);
      return res != key ? res : val;
    }

    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        for (final option in items)
          DropdownMenuItem(value: option, child: Text(getLabel(option))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ============ Lab section ============

class _LabSection extends ConsumerStatefulWidget {
  const _LabSection();

  @override
  ConsumerState<_LabSection> createState() => _LabSectionState();
}

class _LabSectionState extends ConsumerState<_LabSection> {
  final _specimenOtherController = TextEditingController();
  final _cultureOtherController = TextEditingController();
  final _pathogenOtherController = TextEditingController();
  final _antibioticController = TextEditingController();

  @override
  void dispose() {
    _specimenOtherController.dispose();
    _cultureOtherController.dispose();
    _pathogenOtherController.dispose();
    _antibioticController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(AppStrings.get('laboratory_and_amr', lang)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: MutedText(
                        AppStrings.get('lab_description', lang),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.get('lab_performed', lang),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Checkbox(
                    value: state.labPerformed,
                    onChanged: (v) => notifier.setLabPerformed(v ?? false),
                  ),
                ],
              ),
            ],
          ),
          if (state.labPerformed) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(AppStrings.get('specimen_type', lang)),
                      _Dropdown(
                        options: ClinicalCatalog.specimenTypes,
                        value: state.specimenType,
                        onChanged: notifier.setSpecimenType,
                      ),
                      _OtherField(
                        visible: state.showSpecimenTypeOther,
                        value: state.specimenTypeOther,
                        onChanged: notifier.setSpecimenTypeOther,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(AppStrings.get('culture_result', lang)),
                      _Dropdown(
                        options: ClinicalCatalog.cultureResults,
                        value: state.cultureResult,
                        onChanged: notifier.setCultureResult,
                      ),
                      _OtherField(
                        visible: state.showCultureResultOther,
                        value: state.cultureResultOther,
                        onChanged: notifier.setCultureResultOther,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: _FieldLabel(AppStrings.get('identified_pathogen', lang)),
            ),
            _Dropdown(
              options: ClinicalCatalog.pathogens,
              value: state.pathogen,
              onChanged: notifier.setPathogen,
            ),
            _OtherField(
              visible: state.showPathogenOther,
              value: state.pathogenOther,
              onChanged: notifier.setPathogenOther,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: MutedText(AppStrings.get('pathogen_panel_note', lang)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: _FieldLabel(AppStrings.get('antibiotic_tested', lang)),
            ),
            Autocomplete<String>(
              optionsBuilder: (v) => v.text.isEmpty
                  ? ClinicalCatalog.antibiotics
                  : ClinicalCatalog.antibiotics.where(
                      (a) => a.toLowerCase().contains(v.text.toLowerCase()),
                    ),
              onSelected: notifier.setTestedAntibiotic,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: notifier.setTestedAntibiotic,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: _FieldLabel(AppStrings.get('ast_result_label', lang)),
            ),
            _SegmentGroup(
              options: ClinicalCatalog.astResults,
              selected: state.astResult,
              onSelect: notifier.setAstResult,
            ),
            if (state.showResistanceWarning)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('resistant_warning_title', lang),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppStrings.get('resistant_warning_detail', lang),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ============ Prescriptions section ============

class _PrescriptionsSection extends ConsumerWidget {
  const _PrescriptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(submitReportProvider);
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(AppStrings.get('antimicrobial_prescriptions', lang)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: MutedText(
                        AppStrings.get('prescriptions_description', lang),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.get('antibiotic_prescribed', lang),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Checkbox(
                    value: state.antibioticPrescribed,
                    onChanged: (v) =>
                        notifier.setAntibioticPrescribed(v ?? false),
                  ),
                ],
              ),
            ],
          ),
          if (state.antibioticPrescribed) ...[
            const SizedBox(height: 16),
            for (var i = 0; i < state.prescriptions.length; i++)
              _PrescriptionRow(
                index: i,
                draft: state.prescriptions[i],
                notifier: notifier,
              ),
            OutlinedButton(
              onPressed: notifier.addPrescription,
              child: Text(AppStrings.get('add_antibiotic', lang)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrescriptionRow extends ConsumerStatefulWidget {
  final int index;
  final PrescriptionDraft draft;
  final SubmitReportNotifier notifier;

  const _PrescriptionRow({
    required this.index,
    required this.draft,
    required this.notifier,
  });

  @override
  ConsumerState<_PrescriptionRow> createState() => _PrescriptionRowState();
}

class _PrescriptionRowState extends ConsumerState<_PrescriptionRow> {
  late final TextEditingController _drug;
  late final TextEditingController _dosage;
  late final TextEditingController _duration;

  @override
  void initState() {
    super.initState();
    _drug = TextEditingController(text: widget.draft.drugName);
    _dosage = TextEditingController(text: widget.draft.dosage);
    _duration = TextEditingController(text: widget.draft.duration);
  }

  @override
  void dispose() {
    _drug.dispose();
    _dosage.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _update() {
    widget.notifier.updatePrescription(
      widget.index,
      widget.draft.copyWith(
        drugName: _drug.text,
        dosage: _dosage.text,
        duration: _duration.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(AppStrings.get('drug', lang)),
                TextField(
                  controller: _drug,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (_) => _update(),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 320,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(AppStrings.get('dosage', lang)),
                TextField(
                  controller: _dosage,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (_) => _update(),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 320,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(AppStrings.get('duration', lang)),
                TextField(
                  controller: _duration,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (_) => _update(),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => widget.notifier.removePrescription(widget.index),
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ============ Submit bar ============

class _SubmitBar extends ConsumerWidget {
  final SubmitReportState state;
  const _SubmitBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          FilledButton(
            onPressed: state.canSubmit ? () => notifier.submit() : null,
            child: Text(state.isBusy ? AppStrings.get('submitting', lang) : AppStrings.get('submit_report_btn', lang)),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 320,
            child: Builder(
              builder: (context) {
                final missing = state.missingRequirements;
                if (missing.isEmpty) return const SizedBox.shrink();
                final reqText = AppStrings.get('required', lang);
                final missingFields = missing.map((e) {
                  final keyMap = {
                    'patient': 'patient',
                    'patient name': 'patient_name',
                    'valid 10-digit contact number': 'valid_contact',
                    'age': 'age',
                    'sex': 'gender',
                    'district': 'district',
                    'chief complaint': 'complaints',
                    'pathogen': 'pathogen',
                    'pathogen detail': 'pathogen_detail',
                    'specimen detail': 'specimen_detail',
                    'culture detail': 'culture_detail',
                    'syndrome detail': 'syndrome_detail',
                    'outcome detail': 'outcome_detail',
                  };
                  final key = keyMap[e.toLowerCase()] ?? e.toLowerCase().replaceAll(' ', '_');
                  return AppStrings.get(key, lang);
                }).join(', ');
                return MutedText('$reqText: $missingFields');
              },
            ),
          ),
          if (state.errorMessage != null)
            Expanded(
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.statusCritical,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============ Success view ============

class _SuccessView extends ConsumerWidget {
  final SubmitReportState state;
  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(submitReportProvider.notifier);
    final lang = ref.watch(localeProvider);

    return Center(
      child: SectionCard(
        padding: const EdgeInsets.all(40),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCEFE4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.accentGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                AppStrings.get('report_submitted', lang),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              MutedText(state.submittedSummary, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              MutedText(
                AppStrings.get('report_deidentified_note', lang),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  notifier.submitAnother();
                  ShellNav.of(context).navigateTo('dashboard');
                },
                child: Text(AppStrings.get('submit_another_report', lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
