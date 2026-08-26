import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingestion_models.dart';
import '../models/lab_models.dart';
import '../services/api_exceptions.dart';
import '../services/clinical_catalog.dart';
import 'auth.dart';

bool _isOther(String? v) => (v ?? '').trim().toLowerCase() == 'other';

/// Growth without an organism named is an incomplete result, so the pathogen
/// is only required once something actually grew.
bool _isGrowthReported(String? cultureResult) =>
    (cultureResult ?? '').toLowerCase().startsWith('growth');

/// One antibiotic row in the susceptibility panel being edited.
///
/// Immutable value type (not a Riverpod-observed model) so rows can live in
/// a plain `List` on [SubmitIsolateState] and be swapped via `copyWith` on
/// the notifier, matching the state-notifier pattern used elsewhere in this
/// app rather than the WPF client's per-row `ObservableObject`.
class AstRowDraft {
  final String antibiotic;
  final String astResult;
  final String micValue;
  final String micOperator;
  final String zoneDiameter;
  final String method;

  const AstRowDraft({
    this.antibiotic = '',
    this.astResult = '',
    this.micValue = '',
    this.micOperator = '',
    this.zoneDiameter = '',
    this.method = '',
  });

  /// Resolved from the catalog whenever the antibiotic is set, so class-level
  /// analytics (MDR counting) stay consistent without the user typing it.
  String? get antibioticClass => ClinicalCatalog.classFor(antibiotic);

  bool get isComplete => antibiotic.trim().isNotEmpty;

  AstRowDraft copyWith({
    String? antibiotic,
    String? astResult,
    String? micValue,
    String? micOperator,
    String? zoneDiameter,
    String? method,
  }) =>
      AstRowDraft(
        antibiotic: antibiotic ?? this.antibiotic,
        astResult: astResult ?? this.astResult,
        micValue: micValue ?? this.micValue,
        micOperator: micOperator ?? this.micOperator,
        zoneDiameter: zoneDiameter ?? this.zoneDiameter,
        method: method ?? this.method,
      );
}

class SubmitIsolateState {
  final String accessionNo;
  final String collectionDate; // ISO yyyy-MM-dd, or ''
  final String testDate;
  final String specimenType;
  final String specimenTypeOther;
  final String cultureResult;
  final String cultureResultOther;
  final String pathogen;
  final String pathogenOther;
  final String infectionOrigin;
  final String status;
  final String notes;
  final List<AstRowDraft> panel;
  final bool isBusy;
  final bool isSubmitted;
  final String submittedSummary;
  final String? error;
  final String? editingIsolateId;
  final IntelligenceAudit? intelligenceAudit;

  const SubmitIsolateState({
    this.accessionNo = '',
    this.collectionDate = '',
    this.testDate = '',
    this.specimenType = '',
    this.specimenTypeOther = '',
    this.cultureResult = '',
    this.cultureResultOther = '',
    this.pathogen = '',
    this.pathogenOther = '',
    this.infectionOrigin = 'Community-acquired',
    this.status = 'preliminary',
    this.notes = '',
    this.panel = const [],
    this.isBusy = false,
    this.isSubmitted = false,
    this.submittedSummary = '',
    this.error,
    this.editingIsolateId,
    this.intelligenceAudit,
  });

  /// Finalizing/amending a worklist entry rather than recording a new one.
  bool get isEditing => editingIsolateId != null;

  bool get showSpecimenTypeOther => _isOther(specimenType);
  bool get showCultureResultOther => _isOther(cultureResult);
  bool get showPathogenOther => _isOther(pathogen);
  bool get growthReported => _isGrowthReported(cultureResult);

  /// Human-readable list of what's blocking submission, empty when ready.
  /// Mirrors `SubmitIsolateViewModel.MissingRequirements`.
  List<String> missingRequirements() {
    final missing = <String>[];
    if (accessionNo.trim().isEmpty) missing.add('Accession No');
    if (cultureResult.trim().isEmpty) missing.add('Culture Result');
    if (growthReported && pathogen.trim().isEmpty) missing.add('Pathogen');

    if (_isOther(pathogen) && pathogenOther.trim().isEmpty) {
      missing.add('Pathogen detail');
    }
    if (_isOther(specimenType) && specimenTypeOther.trim().isEmpty) {
      missing.add('Specimen detail');
    }
    if (_isOther(cultureResult) && cultureResultOther.trim().isEmpty) {
      missing.add('Culture detail');
    }

    // The same drug twice would be rejected by the server anyway; catching
    // it here explains why instead of surfacing a bare 400.
    final named = panel
        .where((r) => r.isComplete)
        .map((r) => r.antibiotic.trim().toLowerCase())
        .toList();
    if (named.length != named.toSet().length) {
      missing.add('no duplicate antibiotics');
    }

    return missing;
  }

  String get validationSummary {
    final missing = missingRequirements();
    return missing.isEmpty ? '' : 'Required: ${missing.join(', ')}';
  }

  bool get canSubmit => !isBusy && missingRequirements().isEmpty;

  SubmitIsolateState copyWith({
    String? accessionNo,
    String? collectionDate,
    String? testDate,
    String? specimenType,
    String? specimenTypeOther,
    String? cultureResult,
    String? cultureResultOther,
    String? pathogen,
    String? pathogenOther,
    String? infectionOrigin,
    String? status,
    String? notes,
    List<AstRowDraft>? panel,
    bool? isBusy,
    bool? isSubmitted,
    String? submittedSummary,
    String? error,
    String? editingIsolateId,
    IntelligenceAudit? intelligenceAudit,
    bool clearIntelligenceAudit = false,
  }) =>
      SubmitIsolateState(
        accessionNo: accessionNo ?? this.accessionNo,
        collectionDate: collectionDate ?? this.collectionDate,
        testDate: testDate ?? this.testDate,
        specimenType: specimenType ?? this.specimenType,
        specimenTypeOther: specimenTypeOther ?? this.specimenTypeOther,
        cultureResult: cultureResult ?? this.cultureResult,
        cultureResultOther: cultureResultOther ?? this.cultureResultOther,
        pathogen: pathogen ?? this.pathogen,
        pathogenOther: pathogenOther ?? this.pathogenOther,
        infectionOrigin: infectionOrigin ?? this.infectionOrigin,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        panel: panel ?? this.panel,
        isBusy: isBusy ?? this.isBusy,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        submittedSummary: submittedSummary ?? this.submittedSummary,
        error: error,
        editingIsolateId: editingIsolateId ?? this.editingIsolateId,
        intelligenceAudit: clearIntelligenceAudit
            ? null
            : (intelligenceAudit ?? this.intelligenceAudit),
      );
}

final submitIsolateProvider =
    NotifierProvider<SubmitIsolateNotifier, SubmitIsolateState>(SubmitIsolateNotifier.new);

class SubmitIsolateNotifier extends Notifier<SubmitIsolateState> {
  @override
  SubmitIsolateState build() => const SubmitIsolateState();

  void setAccessionNo(String v) => state = state.copyWith(accessionNo: v, error: null);
  void setCollectionDate(String v) => state = state.copyWith(collectionDate: v);
  void setTestDate(String v) => state = state.copyWith(testDate: v);
  void setSpecimenType(String v) => state = state.copyWith(specimenType: v, error: null);
  void setSpecimenTypeOther(String v) => state = state.copyWith(specimenTypeOther: v, error: null);
  void setCultureResult(String v) => state = state.copyWith(cultureResult: v, error: null);
  void setCultureResultOther(String v) => state = state.copyWith(cultureResultOther: v, error: null);
  void setPathogen(String v) => state = state.copyWith(pathogen: v, error: null);
  void setPathogenOther(String v) => state = state.copyWith(pathogenOther: v, error: null);
  void setInfectionOrigin(String v) => state = state.copyWith(infectionOrigin: v);
  void setStatus(String v) => state = state.copyWith(status: v);
  void setNotes(String v) => state = state.copyWith(notes: v);

  void addDrug() => state = state.copyWith(panel: [...state.panel, const AstRowDraft()]);

  void removeDrugAt(int index) {
    final next = [...state.panel]..removeAt(index);
    state = state.copyWith(panel: next);
  }

  void updateDrugAt(int index, AstRowDraft row) {
    final next = [...state.panel];
    next[index] = row;
    state = state.copyWith(panel: next);
  }

  /// Prefills the form from an existing worklist entry so a technician can
  /// finish/correct a pending culture instead of retyping it from scratch.
  /// Submitting from this state amends the isolate rather than creating a
  /// new one (see [submit]).
  void loadForEdit(Isolate isolate) {
    state = SubmitIsolateState(
      accessionNo: isolate.accessionNo ?? '',
      collectionDate: isolate.collectionDate ?? '',
      testDate: isolate.testDate ?? '',
      specimenType: isolate.specimenType ?? '',
      cultureResult: isolate.cultureResult ?? '',
      pathogen: isolate.pathogen ?? '',
      infectionOrigin: isolate.infectionOrigin ?? 'Community-acquired',
      status: isolate.status,
      notes: isolate.notes ?? '',
      panel: [
        for (final a in isolate.astResults)
          AstRowDraft(
            antibiotic: a.antibiotic,
            astResult: a.astResult ?? '',
            micValue: a.micValue?.toString() ?? '',
            micOperator: a.micOperator ?? '',
            zoneDiameter: a.zoneDiameterMm?.toString() ?? '',
            method: a.method ?? '',
          ),
      ],
      editingIsolateId: isolate.isolateId,
    );
  }

  /// Loads the standard Gram-negative panel so a full AST is a few clicks,
  /// replacing whatever rows are currently present.
  void loadStandardPanel() {
    state = state.copyWith(
      panel: [
        for (final drug in ClinicalCatalog.gramNegativePanel) AstRowDraft(antibiotic: drug),
      ],
    );
  }

  /// Builds the request body, matching `SubmitIsolateViewModel.BuildDto`:
  /// blank strings become null, "Other" detail is only carried when "Other"
  /// is actually selected, and incomplete panel rows (no antibiotic named)
  /// are dropped.
  IsolateCreateRequest buildRequest() {
    final s = state;
    String? blank(String v) => v.trim().isEmpty ? null : v.trim();
    String? otherDetail(String coded, String detail) => _isOther(coded) ? blank(detail) : null;

    return IsolateCreateRequest(
      accessionNo: blank(s.accessionNo),
      collectionDate: blank(s.collectionDate),
      testDate: blank(s.testDate),
      specimenType: blank(s.specimenType),
      specimenTypeOther: otherDetail(s.specimenType, s.specimenTypeOther),
      cultureResult: blank(s.cultureResult),
      cultureResultOther: otherDetail(s.cultureResult, s.cultureResultOther),
      pathogen: blank(s.pathogen),
      pathogenOther: otherDetail(s.pathogen, s.pathogenOther),
      infectionOrigin: blank(s.infectionOrigin),
      status: s.status,
      notes: blank(s.notes),
      astResults: [
        for (final row in s.panel.where((r) => r.isComplete))
          AstResultInput(
            antibiotic: row.antibiotic.trim(),
            antibioticClass: row.antibioticClass,
            astResult: blank(row.astResult),
            micValue: double.tryParse(row.micValue.trim()),
            micOperator: blank(row.micOperator),
            zoneDiameterMm: int.tryParse(row.zoneDiameter.trim()),
            method: blank(row.method),
          ),
      ],
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final editingId = state.editingIsolateId;
    state = state.copyWith(isBusy: true, error: null);
    final api = ref.read(apiClientProvider);
    try {
      final result = editingId == null
          ? await api.createIsolate(buildRequest())
          : await api.amendIsolate(editingId, buildRequest());
      final verb = editingId == null ? 'recorded' : 'updated';
      final summary = result.isMdr
          ? '${result.pathogen ?? 'Culture'} $verb — flagged multidrug-resistant (${result.panelSummary}).'
          : '${result.pathogen ?? 'Culture'} $verb (${result.panelSummary}).';
      state = state.copyWith(isBusy: false, isSubmitted: true, submittedSummary: summary);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  /// Resets the form so the next isolate starts clean, matching
  /// `SubmitIsolateViewModel.SubmitAnother`.
  void submitAnother() => state = const SubmitIsolateState();

  // --- OCR Ingestion & Intelligence Validation ---

  void applyOcrResult(OcrParseResult ocr) {
    if (!ocr.intelligenceAudit.isValid && ocr.intelligenceAudit.plausibilityScore == 0) {
      state = state.copyWith(
        intelligenceAudit: ocr.intelligenceAudit,
        error: null,
      );
      return;
    }

    final ext = ocr.extracted;
    final rawPanel = (ext['ast_panel'] as List<dynamic>?) ?? [];

    final parsedRows = rawPanel.map((item) {
      final m = item as Map<String, dynamic>;
      return AstRowDraft(
        antibiotic: m['antibiotic'] as String? ?? '',
        astResult: m['ast_result'] as String? ?? '',
        micValue: m['mic_value']?.toString() ?? '',
        micOperator: m['mic_operator'] as String? ?? '',
        zoneDiameter: m['zone_diameter_mm']?.toString() ?? '',
        method: m['method'] as String? ?? 'Disk diffusion',
      );
    }).toList();

    state = state.copyWith(
      accessionNo: ext['accession_no'] as String? ?? state.accessionNo,
      specimenType: ext['specimen_type'] as String? ?? state.specimenType,
      cultureResult: ext['culture_result'] as String? ?? state.cultureResult,
      pathogen: ext['pathogen'] as String? ?? state.pathogen,
      infectionOrigin: ext['infection_origin'] as String? ?? state.infectionOrigin,
      panel: parsedRows.isNotEmpty ? parsedRows : state.panel,
      intelligenceAudit: ocr.intelligenceAudit,
      error: null,
    );
  }

  Future<void> runIntelligenceValidation() async {
    if (state.specimenType.isEmpty || state.pathogen.isEmpty) return;

    final api = ref.read(apiClientProvider);
    try {
      final panelData = state.panel
          .where((r) => r.isComplete)
          .map((r) => {
                'antibiotic': r.antibiotic,
                'antibiotic_class': r.antibioticClass,
                'ast_result': r.astResult.isEmpty ? null : r.astResult,
                'mic_value': double.tryParse(r.micValue),
                'mic_operator': r.micOperator.isEmpty ? null : r.micOperator,
                'zone_diameter_mm': int.tryParse(r.zoneDiameter),
                'method': r.method.isEmpty ? null : r.method,
              })
          .toList();

      final audit = await api.validateIsolate(
        specimenType: state.specimenType,
        pathogen: state.pathogen,
        astPanel: panelData,
      );
      state = state.copyWith(intelligenceAudit: audit);
    } catch (_) {
      // Non-blocking background intelligence check
    }
  }

  void clearIntelligenceAudit() {
    state = state.copyWith(clearIntelligenceAudit: true);
  }
}
