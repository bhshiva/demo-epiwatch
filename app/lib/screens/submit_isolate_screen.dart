import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/clinical_catalog.dart';
import '../state/submit_isolate.dart';
import '../theme/app_colors.dart';
import '../widgets/intelligence_audit_banner.dart';
import '../widgets/section_card.dart';

/// Record Culture & Susceptibility: one organism per isolate, tested against
/// a panel of antibiotics. Coded fields follow WHO GLASS / ICMR-AMRSN.
class SubmitIsolateScreen extends ConsumerStatefulWidget {
  const SubmitIsolateScreen({super.key});

  @override
  ConsumerState<SubmitIsolateScreen> createState() =>
      _SubmitIsolateScreenState();
}

class _SubmitIsolateScreenState extends ConsumerState<SubmitIsolateScreen> {
  final _accessionCtrl = TextEditingController();
  final _collectionDateCtrl = TextEditingController();
  final _testDateCtrl = TextEditingController();
  final _specimenOtherCtrl = TextEditingController();
  final _cultureOtherCtrl = TextEditingController();
  final _pathogenOtherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _accessionCtrl.dispose();
    _collectionDateCtrl.dispose();
    _testDateCtrl.dispose();
    _specimenOtherCtrl.dispose();
    _cultureOtherCtrl.dispose();
    _pathogenOtherCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFrom(SubmitIsolateState s) {
    _syncText(_accessionCtrl, s.accessionNo);
    _syncText(_collectionDateCtrl, s.collectionDate);
    _syncText(_testDateCtrl, s.testDate);
    _syncText(_specimenOtherCtrl, s.specimenTypeOther);
    _syncText(_cultureOtherCtrl, s.cultureResultOther);
    _syncText(_pathogenOtherCtrl, s.pathogenOther);
    _syncText(_notesCtrl, s.notes);
  }

  void _syncText(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.value = ctrl.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  Future<void> _pickDate(
    TextEditingController ctrl,
    void Function(String) onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      final iso =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      onPicked(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitIsolateProvider);
    final notifier = ref.read(submitIsolateProvider.notifier);
    _syncControllersFrom(state);

    if (state.isSubmitted) {
      return _SuccessView(
        summary: state.submittedSummary,
        onSubmitAnother: notifier.submitAnother,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.isEditing
                  ? 'Finalize Culture Result'
                  : 'Record Culture & Susceptibility',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            MutedText(
              state.isEditing
                  ? 'Completing accession ${state.accessionNo.isEmpty ? '—' : state.accessionNo} from the worklist. '
                        'Submitting supersedes the pending result with this one.'
                  : 'One organism per isolate, tested against a panel of antibiotics. '
                        'Coded fields follow WHO GLASS and ICMR-AMRSN vocabularies.',
            ),
            const SizedBox(height: 22),
            if (state.intelligenceAudit != null)
              IntelligenceAuditBanner(
                audit: state.intelligenceAudit!,
                onDismiss: notifier.clearIntelligenceAudit,
              ),
            if (state.error != null) ...[
              _ErrorBanner(message: state.error!),
              const SizedBox(height: 18),
            ],
            SectionCard(
              margin: const EdgeInsets.only(bottom: 18),
              child: _SpecimenSection(
                state: state,
                notifier: notifier,
                accessionCtrl: _accessionCtrl,
                collectionDateCtrl: _collectionDateCtrl,
                testDateCtrl: _testDateCtrl,
                specimenOtherCtrl: _specimenOtherCtrl,
                onPickCollectionDate: () =>
                    _pickDate(_collectionDateCtrl, notifier.setCollectionDate),
                onPickTestDate: () =>
                    _pickDate(_testDateCtrl, notifier.setTestDate),
              ),
            ),
            SectionCard(
              margin: const EdgeInsets.only(bottom: 18),
              child: _CultureSection(
                state: state,
                notifier: notifier,
                cultureOtherCtrl: _cultureOtherCtrl,
                pathogenOtherCtrl: _pathogenOtherCtrl,
              ),
            ),
            SectionCard(
              margin: const EdgeInsets.only(bottom: 18),
              child: _DetailsSection(
                state: state,
                notifier: notifier,
                notesCtrl: _notesCtrl,
              ),
            ),
            SectionCard(
              margin: const EdgeInsets.only(bottom: 18),
              child: _AstPanelSection(state: state, notifier: notifier),
            ),
            if (state.validationSummary.isNotEmpty) ...[
              MutedText(state.validationSummary),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (state.isEditing) ...[
                  TextButton(
                    onPressed: state.isBusy ? null : notifier.submitAnother,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton(
                  onPressed: state.canSubmit ? notifier.submit : null,
                  child: state.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(state.isEditing ? 'Save Result' : 'Submit Result'),
                ),
              ],
            ),
          ],
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
      border: Border.all(
        color: AppColors.statusCritical.withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline,
          color: AppColors.statusCritical,
          size: 18,
        ),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.statusCritical,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
  );
}

InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
  isDense: true,
  hintText: hint,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
);

class _SpecimenSection extends StatelessWidget {
  final SubmitIsolateState state;
  final SubmitIsolateNotifier notifier;
  final TextEditingController accessionCtrl;
  final TextEditingController collectionDateCtrl;
  final TextEditingController testDateCtrl;
  final TextEditingController specimenOtherCtrl;
  final VoidCallback onPickCollectionDate;
  final VoidCallback onPickTestDate;

  const _SpecimenSection({
    required this.state,
    required this.notifier,
    required this.accessionCtrl,
    required this.collectionDateCtrl,
    required this.testDateCtrl,
    required this.specimenOtherCtrl,
    required this.onPickCollectionDate,
    required this.onPickTestDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Specimen'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            final fields = [
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 40) / 3
                    : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Accession No *'),
                    TextField(
                      controller: accessionCtrl,
                      decoration: _fieldDecoration(),
                      onChanged: notifier.setAccessionNo,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 40) / 3
                    : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Collection Date'),
                    TextField(
                      controller: collectionDateCtrl,
                      readOnly: true,
                      decoration: _fieldDecoration(hint: 'YYYY-MM-DD').copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                      ),
                      onTap: onPickCollectionDate,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 40) / 3
                    : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Test Date'),
                    TextField(
                      controller: testDateCtrl,
                      readOnly: true,
                      decoration: _fieldDecoration(hint: 'YYYY-MM-DD').copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                      ),
                      onTap: onPickTestDate,
                    ),
                  ],
                ),
              ),
            ];
            return Wrap(spacing: 20, runSpacing: 16, children: fields);
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Specimen Type'),
        DropdownButtonFormField<String>(
          initialValue: state.specimenType.isEmpty ? null : state.specimenType,
          decoration: _fieldDecoration(),
          items: [
            for (final v in ClinicalCatalog.specimenTypes)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => notifier.setSpecimenType(v ?? ''),
        ),
        if (state.showSpecimenTypeOther) ...[
          const SizedBox(height: 8),
          TextField(
            controller: specimenOtherCtrl,
            decoration: _fieldDecoration(hint: 'Specify specimen type'),
            onChanged: notifier.setSpecimenTypeOther,
          ),
        ],
      ],
    );
  }
}

class _CultureSection extends StatelessWidget {
  final SubmitIsolateState state;
  final SubmitIsolateNotifier notifier;
  final TextEditingController cultureOtherCtrl;
  final TextEditingController pathogenOtherCtrl;

  const _CultureSection({
    required this.state,
    required this.notifier,
    required this.cultureOtherCtrl,
    required this.pathogenOtherCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Culture'),
        const SizedBox(height: 16),
        const _FieldLabel('Culture Result *'),
        DropdownButtonFormField<String>(
          initialValue: state.cultureResult.isEmpty
              ? null
              : state.cultureResult,
          decoration: _fieldDecoration(),
          items: [
            for (final v in ClinicalCatalog.cultureResults)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => notifier.setCultureResult(v ?? ''),
        ),
        if (state.showCultureResultOther) ...[
          const SizedBox(height: 8),
          TextField(
            controller: cultureOtherCtrl,
            decoration: _fieldDecoration(hint: 'Specify culture result'),
            onChanged: notifier.setCultureResultOther,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Pathogen${state.growthReported ? ' *' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: state.pathogen.isEmpty ? null : state.pathogen,
          decoration: _fieldDecoration(
            hint: state.growthReported
                ? null
                : 'Not applicable — no growth reported',
          ),
          items: [
            for (final v in ClinicalCatalog.pathogens)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => notifier.setPathogen(v ?? ''),
        ),
        if (state.showPathogenOther) ...[
          const SizedBox(height: 8),
          TextField(
            controller: pathogenOtherCtrl,
            decoration: _fieldDecoration(hint: 'Specify organism'),
            onChanged: notifier.setPathogenOther,
          ),
        ],
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final SubmitIsolateState state;
  final SubmitIsolateNotifier notifier;
  final TextEditingController notesCtrl;

  const _DetailsSection({
    required this.state,
    required this.notifier,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Details'),
        const SizedBox(height: 16),
        const _FieldLabel('Infection Origin'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final origin in ClinicalCatalog.infectionOrigins)
              ChoiceChip(
                label: Text(origin),
                selected: state.infectionOrigin == origin,
                onSelected: (_) => notifier.setInfectionOrigin(origin),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Status'),
        DropdownButtonFormField<String>(
          initialValue: state.status,
          decoration: _fieldDecoration(),
          items: [
            for (final v in ClinicalCatalog.isolateStatuses)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => notifier.setStatus(v ?? state.status),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Notes'),
        TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: _fieldDecoration(),
          onChanged: notifier.setNotes,
        ),
      ],
    );
  }
}

class _AstPanelSection extends StatelessWidget {
  final SubmitIsolateState state;
  final SubmitIsolateNotifier notifier;

  const _AstPanelSection({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Susceptibility Panel')),
            TextButton.icon(
              onPressed: notifier.loadStandardPanel,
              icon: const Icon(Icons.playlist_add_check, size: 18),
              label: const Text('Load standard panel'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: notifier.addDrug,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add drug'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.panel.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: MutedText(
              'No antibiotics added yet. Add a drug or load the standard panel.',
            ),
          )
        else
          for (var i = 0; i < state.panel.length; i++)
            _AstRow(
              key: ValueKey('ast-row-$i'),
              index: i,
              row: state.panel[i],
              notifier: notifier,
            ),
      ],
    );
  }
}

class _AstRow extends StatefulWidget {
  final int index;
  final AstRowDraft row;
  final SubmitIsolateNotifier notifier;

  const _AstRow({
    super.key,
    required this.index,
    required this.row,
    required this.notifier,
  });

  @override
  State<_AstRow> createState() => _AstRowState();
}

class _AstRowState extends State<_AstRow> {
  late final TextEditingController _micValueCtrl;
  late final TextEditingController _zoneCtrl;
  late final TextEditingController _antibioticCtrl;

  @override
  void initState() {
    super.initState();
    _micValueCtrl = TextEditingController(text: widget.row.micValue);
    _zoneCtrl = TextEditingController(text: widget.row.zoneDiameter);
    _antibioticCtrl = TextEditingController(text: widget.row.antibiotic);
  }

  @override
  void didUpdateWidget(covariant _AstRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_micValueCtrl.text != widget.row.micValue) {
      _micValueCtrl.text = widget.row.micValue;
    }
    if (_zoneCtrl.text != widget.row.zoneDiameter) {
      _zoneCtrl.text = widget.row.zoneDiameter;
    }
    if (_antibioticCtrl.text != widget.row.antibiotic) {
      _antibioticCtrl.text = widget.row.antibiotic;
    }
  }

  @override
  void dispose() {
    _micValueCtrl.dispose();
    _zoneCtrl.dispose();
    _antibioticCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(text: row.antibiotic),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return ClinicalCatalog.antibiotics;
                    }
                    return ClinicalCatalog.antibiotics.where(
                      (a) => a.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (value) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(antibiotic: value),
                  ),
                  fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      decoration: _fieldDecoration(hint: 'Antibiotic'),
                      onChanged: (v) => widget.notifier.updateDrugAt(
                        widget.index,
                        row.copyWith(antibiotic: v),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 320,
                child: IgnorePointer(
                  child: TextField(
                    enabled: false,
                    decoration: _fieldDecoration(
                      hint: 'Class (auto)',
                    ).copyWith(hintText: row.antibioticClass ?? 'Class (auto)'),
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  initialValue: row.astResult.isEmpty ? null : row.astResult,
                  decoration: _fieldDecoration(hint: 'Result'),
                  items: [
                    for (final v in ClinicalCatalog.astResults)
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(astResult: v ?? ''),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => widget.notifier.removeDrugAt(widget.index),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: row.micOperator.isEmpty
                      ? null
                      : row.micOperator,
                  decoration: _fieldDecoration(hint: 'MIC operator'),
                  items: [
                    for (final v in ClinicalCatalog.micOperators)
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(micOperator: v ?? ''),
                  ),
                ),
              ),
              SizedBox(
                width: 320,

                child: TextField(
                  controller: _micValueCtrl,
                  decoration: _fieldDecoration(hint: 'MIC value'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(micValue: v),
                  ),
                ),
              ),
              SizedBox(
                width: 320,

                child: TextField(
                  controller: _zoneCtrl,
                  decoration: _fieldDecoration(hint: 'Zone (mm)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(zoneDiameter: v),
                  ),
                ),
              ),
              SizedBox(
                width: 320,

                child: DropdownButtonFormField<String>(
                  initialValue: row.method.isEmpty ? null : row.method,
                  decoration: _fieldDecoration(hint: 'Method'),
                  items: [
                    for (final v in ClinicalCatalog.astMethods)
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => widget.notifier.updateDrugAt(
                    widget.index,
                    row.copyWith(method: v ?? ''),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String summary;
  final VoidCallback onSubmitAnother;

  const _SuccessView({required this.summary, required this.onSubmitAnother});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 460,
        child: SectionCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEFE4),
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check,
                  color: AppColors.accentGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Result Recorded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              MutedText(summary, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onSubmitAnother,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Record Another'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
