import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_models.dart';
import '../models/report_models.dart';
import '../services/api_exceptions.dart';
import '../services/clinical_catalog.dart';
import 'auth.dart';

bool _isOther(String? value) => value != null && value.toLowerCase() == 'other';

String? _blank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Free-text detail only survives while its coded value is "Other" — mirrors
/// `OtherDetail` in the WPF SubmitReportViewModel so text typed and then
/// abandoned (after switching the dropdown away from "Other") is never sent.
String? _otherDetail(String? coded, String? detail) => _isOther(coded) ? _blank(detail) : null;

class PrescriptionDraft {
  final String drugName;
  final String dosage;
  final String duration;

  const PrescriptionDraft({this.drugName = '', this.dosage = '', this.duration = ''});

  bool get isComplete => drugName.trim().isNotEmpty;

  PrescriptionDraft copyWith({String? drugName, String? dosage, String? duration}) =>
      PrescriptionDraft(
        drugName: drugName ?? this.drugName,
        dosage: dosage ?? this.dosage,
        duration: duration ?? this.duration,
      );
}

/// State for the Submit Report screen. Mirrors the fields of
/// `SubmitReportViewModel.cs` in the WPF client — see that file for the field
/// shapes this was ported from.
class SubmitReportState {
  // --- Patient search / identity continuity ---
  final String patientSearchText;
  final bool isSearching;
  final List<PatientSearchResult> searchResults;
  final String? searchMessage;

  final PatientSearchResult? selectedPatient;
  final bool isRegisteringNewPatient;
  final bool isLoadingHistory;
  final List<PatientHistoryEntry> patientHistory;

  // --- New patient fields ---
  final String newPatientName;
  final String newPatientMrn;
  final String newPatientContact;
  final DateTime? newPatientDob;
  final String newPatientAbha;
  final AbhaVerifyResult? abhaResult;
  final bool isVerifyingAbha;

  final bool isCheckingDuplicates;
  final List<PatientMatchCandidate> nearMatches;
  final bool duplicateOverrideConfirmed;

  // --- Patient context ---
  final String patientAge;
  final String patientSex;
  final String patientDistrict;

  // --- Clinical summary ---
  final String complaints;
  final String medicalHistory;
  final List<String> symptoms;

  // --- Diagnosis ---
  final String diagnosis;
  final String diagnosisStatus;
  final String treatment;

  // --- ACORN ---
  final String infectionSyndrome;
  final String infectionSyndromeOther;
  final String infectionOrigin;
  final String patientOutcome;
  final String patientOutcomeOther;

  // --- Lab & AMR ---
  final bool labPerformed;
  final String specimenType;
  final String specimenTypeOther;
  final String cultureResult;
  final String cultureResultOther;
  final String pathogen;
  final String pathogenOther;
  final String testedAntibiotic;
  final String astResult;

  // --- Prescriptions ---
  final bool antibioticPrescribed;
  final List<PrescriptionDraft> prescriptions;

  // --- Submission ---
  final bool isBusy;
  final String? errorMessage;
  final bool isSubmitted;
  final String submittedSummary;

  const SubmitReportState({
    this.patientSearchText = '',
    this.isSearching = false,
    this.searchResults = const [],
    this.searchMessage,
    this.selectedPatient,
    this.isRegisteringNewPatient = false,
    this.isLoadingHistory = false,
    this.patientHistory = const [],
    this.newPatientName = '',
    this.newPatientMrn = '',
    this.newPatientContact = '',
    this.newPatientDob,
    this.newPatientAbha = '',
    this.abhaResult,
    this.isVerifyingAbha = false,
    this.isCheckingDuplicates = false,
    this.nearMatches = const [],
    this.duplicateOverrideConfirmed = false,
    this.patientAge = '',
    this.patientSex = '',
    this.patientDistrict = '',
    this.complaints = '',
    this.medicalHistory = '',
    this.symptoms = const [],
    this.diagnosis = '',
    this.diagnosisStatus = 'Suspected',
    this.treatment = '',
    this.infectionSyndrome = '',
    this.infectionSyndromeOther = '',
    this.infectionOrigin = 'Community-acquired',
    this.patientOutcome = 'Not yet known',
    this.patientOutcomeOther = '',
    this.labPerformed = false,
    this.specimenType = '',
    this.specimenTypeOther = '',
    this.cultureResult = '',
    this.cultureResultOther = '',
    this.pathogen = '',
    this.pathogenOther = '',
    this.testedAntibiotic = '',
    this.astResult = '',
    this.antibioticPrescribed = false,
    this.prescriptions = const [],
    this.isBusy = false,
    this.errorMessage,
    this.isSubmitted = false,
    this.submittedSummary = '',
  });

  bool get hasSelectedPatient => selectedPatient != null;
  bool get isNewPatient => isRegisteringNewPatient && selectedPatient == null;
  bool get hasAbhaResult => abhaResult != null;
  bool get hasNearMatches => nearMatches.isNotEmpty;

  bool get showInfectionSyndromeOther => _isOther(infectionSyndrome);
  bool get showPatientOutcomeOther => _isOther(patientOutcome);
  bool get showSpecimenTypeOther => _isOther(specimenType);
  bool get showCultureResultOther => _isOther(cultureResult);
  bool get showPathogenOther => _isOther(pathogen);
  bool get showResistanceWarning => astResult.toLowerCase() == 'resistant';

  /// Age from date of birth when known (recomputed on each visit so it never
  /// goes stale), else the typed value.
  int? get effectiveAge {
    if (newPatientDob != null) {
      final dob = newPatientDob!;
      final today = DateTime.now();
      var years = today.year - dob.year;
      final hadBirthdayThisYear = (today.month > dob.month) ||
          (today.month == dob.month && today.day >= dob.day);
      if (!hadBirthdayThisYear) years--;
      if (years >= 0 && years <= 120) return years;
    }
    final typed = int.tryParse(patientAge.trim());
    if (typed != null && typed >= 0 && typed <= 120) return typed;
    return null;
  }

  String get derivedAgeGroup {
    final age = effectiveAge;
    return age == null ? '' : ClinicalCatalog.ageGroupFor(age);
  }
  bool get isContactValid {
    final trimmed = newPatientContact.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^\d{10}$').hasMatch(trimmed);
  }

  bool get isAgeValid {
    final trimmed = patientAge.trim();
    if (trimmed.isEmpty) return true;
    final val = int.tryParse(trimmed);
    return val != null && val >= 0 && val <= 120;
  }

  /// What still blocks submission, in the same order/spirit as
  /// `MissingRequirements()` in the WPF ViewModel.
  List<String> get missingRequirements {
    final missing = <String>[];
    if (selectedPatient == null && !isRegisteringNewPatient) missing.add('Patient');
    if (isNewPatient && newPatientName.trim().isEmpty) missing.add('Patient Name');
    if (isNewPatient && !isContactValid) missing.add('Valid 10-digit Contact Number');

    if (derivedAgeGroup.isEmpty || !isAgeValid) missing.add('Age');
    if (patientSex.trim().isEmpty) missing.add('Sex');
    if (patientDistrict.trim().isEmpty) missing.add('District');
    if (complaints.trim().isEmpty) missing.add('Chief Complaint');
    if (labPerformed && pathogen.trim().isEmpty) missing.add('Pathogen');
    if (labPerformed && _isOther(pathogen) && pathogenOther.trim().isEmpty) {
      missing.add('Pathogen detail');
    }
    if (labPerformed && _isOther(specimenType) && specimenTypeOther.trim().isEmpty) {
      missing.add('Specimen detail');
    }
    if (labPerformed && _isOther(cultureResult) && cultureResultOther.trim().isEmpty) {
      missing.add('Culture detail');
    }
    if (_isOther(infectionSyndrome) && infectionSyndromeOther.trim().isEmpty) {
      missing.add('Syndrome detail');
    }
    if (_isOther(patientOutcome) && patientOutcomeOther.trim().isEmpty) {
      missing.add('Outcome detail');
    }
    return missing;
  }

  String get validationSummary {
    final missing = missingRequirements;
    return missing.isEmpty ? '' : 'Required: ${missing.join(', ')}';
  }

  bool get canSubmit => !isBusy && missingRequirements.isEmpty;

  /// The new-patient identity fields, shared by the duplicate-match check and
  /// the final submit — mirrors `BuildIdentityDto()`.
  PatientIdentityInput buildIdentity() => PatientIdentityInput(
        fullName: newPatientName.trim(),
        dateOfBirth: newPatientDob == null
            ? null
            : '${newPatientDob!.year.toString().padLeft(4, '0')}-'
                '${newPatientDob!.month.toString().padLeft(2, '0')}-'
                '${newPatientDob!.day.toString().padLeft(2, '0')}',
        exactAge: effectiveAge,
        contactNumber: _blank(newPatientContact),
        facilityMrn: _blank(newPatientMrn),
        abhaId: _blank(newPatientAbha),
        district: _blank(patientDistrict),
      );

  /// Builds the request body — mirrors `BuildDto()`.
  ReportCreateRequest buildRequest() {
    final today = DateTime.now();
    final reportDate = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    return ReportCreateRequest(
      patientId: selectedPatient?.patientId,
      patientIdentity: isNewPatient && newPatientName.trim().isNotEmpty ? buildIdentity() : null,
      confirmedNew: duplicateOverrideConfirmed,
      patientExactAge: effectiveAge,
      patientAgeGroup: derivedAgeGroup,
      patientSex: patientSex,
      patientDistrict: patientDistrict,
      reportDate: reportDate,
      complaints: _blank(complaints),
      medicalHistory: _blank(medicalHistory),
      symptoms: symptoms,
      diagnosis: _blank(diagnosis),
      diagnosisStatus: diagnosisStatus,
      treatment: _blank(treatment),
      infectionSyndrome: _blank(infectionSyndrome),
      infectionSyndromeOther: _otherDetail(infectionSyndrome, infectionSyndromeOther),
      infectionOrigin: _blank(infectionOrigin),
      patientOutcome: _blank(patientOutcome),
      patientOutcomeOther: _otherDetail(patientOutcome, patientOutcomeOther),
      prescriptions: antibioticPrescribed
          ? prescriptions
              .where((p) => p.isComplete)
              .map((p) => Prescription(
                    drugName: p.drugName.trim(),
                    dosage: _blank(p.dosage),
                    duration: _blank(p.duration),
                  ))
              .toList()
          : const [],
      labResult: labPerformed
          ? LabResultInput(
              testDate: reportDate,
              specimenType: _blank(specimenType),
              specimenTypeOther: _otherDetail(specimenType, specimenTypeOther),
              cultureResult: _blank(cultureResult),
              cultureResultOther: _otherDetail(cultureResult, cultureResultOther),
              pathogen: _blank(pathogen),
              pathogenOther: _otherDetail(pathogen, pathogenOther),
              antibiotic: _blank(testedAntibiotic),
              astResult: _blank(astResult),
            )
          : null,
    );
  }

  SubmitReportState copyWith({
    String? patientSearchText,
    bool? isSearching,
    List<PatientSearchResult>? searchResults,
    String? searchMessage,
    bool clearSearchMessage = false,
    PatientSearchResult? selectedPatient,
    bool clearSelectedPatient = false,
    bool? isRegisteringNewPatient,
    bool? isLoadingHistory,
    List<PatientHistoryEntry>? patientHistory,
    String? newPatientName,
    String? newPatientMrn,
    String? newPatientContact,
    DateTime? newPatientDob,
    bool clearNewPatientDob = false,
    String? newPatientAbha,
    AbhaVerifyResult? abhaResult,
    bool clearAbhaResult = false,
    bool? isVerifyingAbha,
    bool? isCheckingDuplicates,
    List<PatientMatchCandidate>? nearMatches,
    bool? duplicateOverrideConfirmed,
    String? patientAge,
    String? patientSex,
    String? patientDistrict,
    String? complaints,
    String? medicalHistory,
    List<String>? symptoms,
    String? diagnosis,
    String? diagnosisStatus,
    String? treatment,
    String? infectionSyndrome,
    String? infectionSyndromeOther,
    String? infectionOrigin,
    String? patientOutcome,
    String? patientOutcomeOther,
    bool? labPerformed,
    String? specimenType,
    String? specimenTypeOther,
    String? cultureResult,
    String? cultureResultOther,
    String? pathogen,
    String? pathogenOther,
    String? testedAntibiotic,
    String? astResult,
    bool? antibioticPrescribed,
    List<PrescriptionDraft>? prescriptions,
    bool? isBusy,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isSubmitted,
    String? submittedSummary,
  }) {
    return SubmitReportState(
      patientSearchText: patientSearchText ?? this.patientSearchText,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
      searchMessage: clearSearchMessage ? null : (searchMessage ?? this.searchMessage),
      selectedPatient: clearSelectedPatient ? null : (selectedPatient ?? this.selectedPatient),
      isRegisteringNewPatient: isRegisteringNewPatient ?? this.isRegisteringNewPatient,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      patientHistory: patientHistory ?? this.patientHistory,
      newPatientName: newPatientName ?? this.newPatientName,
      newPatientMrn: newPatientMrn ?? this.newPatientMrn,
      newPatientContact: newPatientContact ?? this.newPatientContact,
      newPatientDob: clearNewPatientDob ? null : (newPatientDob ?? this.newPatientDob),
      newPatientAbha: newPatientAbha ?? this.newPatientAbha,
      abhaResult: clearAbhaResult ? null : (abhaResult ?? this.abhaResult),
      isVerifyingAbha: isVerifyingAbha ?? this.isVerifyingAbha,
      isCheckingDuplicates: isCheckingDuplicates ?? this.isCheckingDuplicates,
      nearMatches: nearMatches ?? this.nearMatches,
      duplicateOverrideConfirmed: duplicateOverrideConfirmed ?? this.duplicateOverrideConfirmed,
      patientAge: patientAge ?? this.patientAge,
      patientSex: patientSex ?? this.patientSex,
      patientDistrict: patientDistrict ?? this.patientDistrict,
      complaints: complaints ?? this.complaints,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
      treatment: treatment ?? this.treatment,
      infectionSyndrome: infectionSyndrome ?? this.infectionSyndrome,
      infectionSyndromeOther: infectionSyndromeOther ?? this.infectionSyndromeOther,
      infectionOrigin: infectionOrigin ?? this.infectionOrigin,
      patientOutcome: patientOutcome ?? this.patientOutcome,
      patientOutcomeOther: patientOutcomeOther ?? this.patientOutcomeOther,
      labPerformed: labPerformed ?? this.labPerformed,
      specimenType: specimenType ?? this.specimenType,
      specimenTypeOther: specimenTypeOther ?? this.specimenTypeOther,
      cultureResult: cultureResult ?? this.cultureResult,
      cultureResultOther: cultureResultOther ?? this.cultureResultOther,
      pathogen: pathogen ?? this.pathogen,
      pathogenOther: pathogenOther ?? this.pathogenOther,
      testedAntibiotic: testedAntibiotic ?? this.testedAntibiotic,
      astResult: astResult ?? this.astResult,
      antibioticPrescribed: antibioticPrescribed ?? this.antibioticPrescribed,
      prescriptions: prescriptions ?? this.prescriptions,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSubmitted: isSubmitted ?? this.isSubmitted,
      submittedSummary: submittedSummary ?? this.submittedSummary,
    );
  }
}

final submitReportProvider =
    NotifierProvider<SubmitReportNotifier, SubmitReportState>(SubmitReportNotifier.new);

class SubmitReportNotifier extends Notifier<SubmitReportState> {
  @override
  SubmitReportState build() => const SubmitReportState();

  // --- Patient lookup ---

  void setPatientSearchText(String value) {
    state = state.copyWith(patientSearchText: value);
  }

  Future<void> searchPatients() async {
    final term = state.patientSearchText.trim();
    if (term.isEmpty) return;

    state = state.copyWith(isSearching: true, clearSearchMessage: true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await api.searchPatients(term);
      state = state.copyWith(
        isSearching: false,
        searchResults: results,
        searchMessage: results.isEmpty ? 'No patient matching "$term" at this facility.' : null,
        clearSearchMessage: results.isNotEmpty,
      );
    } on NetworkException {
      state = state.copyWith(
        isSearching: false,
        searchMessage: 'Could not reach the server. You can still register the patient as new.',
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSearching: false, searchMessage: e.message);
    }
  }

  Future<void> selectPatient(PatientSearchResult patient) async {
    state = state.copyWith(
      selectedPatient: patient,
      isRegisteringNewPatient: false,
      searchResults: const [],
      clearSearchMessage: true,
      patientAge: patient.exactAge?.toString() ?? state.patientAge,
      patientSex: patient.sex,
      patientDistrict: patient.district,
      patientHistory: const [],
      isLoadingHistory: true,
    );

    final api = ref.read(apiClientProvider);
    try {
      final history = await api.patientHistory(patient.patientId);
      state = state.copyWith(isLoadingHistory: false, patientHistory: history);
    } on ApiException {
      state = state.copyWith(
        isLoadingHistory: false,
        searchMessage: 'Patient selected, but their history could not be loaded.',
      );
    } on NetworkException {
      state = state.copyWith(
        isLoadingHistory: false,
        searchMessage: 'Patient selected, but their history could not be loaded.',
      );
    }
  }

  /// Advisory-only lookup while the clinician is still typing. A failed
  /// lookup must not block them — the server enforces the real check on
  /// submit — so errors here are swallowed, matching the WPF ViewModel.
  Future<void> checkForDuplicates() async {
    if (!state.isNewPatient || state.newPatientName.trim().length < 3) {
      state = state.copyWith(nearMatches: const []);
      return;
    }

    state = state.copyWith(isCheckingDuplicates: true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await api.matchPatients(state.buildIdentity().toJson());
      state = state.copyWith(isCheckingDuplicates: false, nearMatches: results);
    } on ApiException {
      state = state.copyWith(isCheckingDuplicates: false);
    } on NetworkException {
      state = state.copyWith(isCheckingDuplicates: false);
    }
  }

  Future<void> verifyAbha() async {
    if (state.newPatientAbha.trim().isEmpty) {
      state = state.copyWith(clearAbhaResult: true);
      return;
    }

    state = state.copyWith(isVerifyingAbha: true);
    final api = ref.read(apiClientProvider);
    try {
      final result = await api.verifyAbha(state.newPatientAbha.trim());
      state = state.copyWith(isVerifyingAbha: false, abhaResult: result);

      // Registry data outranks what was typed at the counter.
      if (result.verified) {
        state = state.copyWith(
          newPatientName: (result.name != null && result.name!.isNotEmpty)
              ? result.name!
              : state.newPatientName,
          patientSex:
              (result.gender != null && result.gender!.isNotEmpty) ? result.gender! : state.patientSex,
          patientDistrict: (result.stateName != null && result.stateName!.isNotEmpty)
              ? result.stateName!
              : state.patientDistrict,
          newPatientDob: _tryParseDate(result.dateOfBirth) ?? state.newPatientDob,
          newPatientAbha: (result.abhaNumber != null && result.abhaNumber!.isNotEmpty)
              ? result.abhaNumber!
              : state.newPatientAbha,
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        isVerifyingAbha: false,
        abhaResult: AbhaVerifyResult(isValid: false, verified: false),
        errorMessage: e.message,
      );
    } on NetworkException {
      state = state.copyWith(
        isVerifyingAbha: false,
        abhaResult: const AbhaVerifyResult(isValid: false, verified: false),
      );
    }
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> useExistingPatient(PatientMatchCandidate candidate) async {
    state = state.copyWith(nearMatches: const []);
    await selectPatient(candidate);
  }

  void createAnyway() {
    state = state.copyWith(duplicateOverrideConfirmed: true, nearMatches: const []);
  }

  void startNewPatient() {
    state = state.copyWith(
      clearSelectedPatient: true,
      isRegisteringNewPatient: true,
      newPatientName: state.patientSearchText.trim(),
      searchResults: const [],
      patientHistory: const [],
      clearSearchMessage: true,
    );
  }

  void clearPatient() {
    state = state.copyWith(
      clearSelectedPatient: true,
      isRegisteringNewPatient: false,
      newPatientName: '',
      newPatientMrn: '',
      newPatientContact: '',
      clearNewPatientDob: true,
      newPatientAbha: '',
      clearAbhaResult: true,
      duplicateOverrideConfirmed: false,
      nearMatches: const [],
      patientSearchText: '',
      searchResults: const [],
      patientHistory: const [],
      clearSearchMessage: true,
      patientAge: '',
      patientSex: '',
      patientDistrict: '',
    );
  }

  // --- Patient context fields ---

  void setPatientAge(String value) => state = state.copyWith(patientAge: value);
  void setPatientSex(String value) => state = state.copyWith(patientSex: value);
  void setPatientDistrict(String value) => state = state.copyWith(patientDistrict: value);
  void setNewPatientName(String value) => state = state.copyWith(newPatientName: value);
  void setNewPatientMrn(String value) => state = state.copyWith(newPatientMrn: value);
  void setNewPatientContact(String value) => state = state.copyWith(newPatientContact: value);
  void setNewPatientDob(DateTime? value) => value == null
      ? state = state.copyWith(clearNewPatientDob: true)
      : state = state.copyWith(newPatientDob: value);
  void setNewPatientAbha(String value) => state = state.copyWith(newPatientAbha: value);

  // --- Clinical summary ---

  void setComplaints(String value) => state = state.copyWith(complaints: value);
  void setMedicalHistory(String value) => state = state.copyWith(medicalHistory: value);

  void toggleSymptom(String symptom) {
    final trimmed = symptom.trim();
    if (trimmed.isEmpty) return;
    final existing =
        state.symptoms.where((s) => s.toLowerCase() == trimmed.toLowerCase()).toList();
    if (existing.isNotEmpty) {
      state = state.copyWith(
          symptoms: state.symptoms.where((s) => s != existing.first).toList());
    } else {
      state = state.copyWith(symptoms: [...state.symptoms, trimmed]);
    }
  }

  void addSymptom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (state.symptoms.any((s) => s.toLowerCase() == trimmed.toLowerCase())) return;
    state = state.copyWith(symptoms: [...state.symptoms, trimmed]);
  }

  void removeSymptom(String symptom) {
    state = state.copyWith(symptoms: state.symptoms.where((s) => s != symptom).toList());
  }

  // --- Diagnosis ---

  void setDiagnosis(String value) => state = state.copyWith(diagnosis: value);
  void setDiagnosisStatus(String value) => state = state.copyWith(diagnosisStatus: value);
  void setTreatment(String value) => state = state.copyWith(treatment: value);

  // --- ACORN ---

  void setInfectionSyndrome(String value) => state = state.copyWith(infectionSyndrome: value);
  void setInfectionSyndromeOther(String value) =>
      state = state.copyWith(infectionSyndromeOther: value);
  void setInfectionOrigin(String value) => state = state.copyWith(infectionOrigin: value);
  void setPatientOutcome(String value) => state = state.copyWith(patientOutcome: value);
  void setPatientOutcomeOther(String value) => state = state.copyWith(patientOutcomeOther: value);

  // --- Lab & AMR ---

  void setLabPerformed(bool value) => state = state.copyWith(labPerformed: value);
  void setSpecimenType(String value) => state = state.copyWith(specimenType: value);
  void setSpecimenTypeOther(String value) => state = state.copyWith(specimenTypeOther: value);
  void setCultureResult(String value) => state = state.copyWith(cultureResult: value);
  void setCultureResultOther(String value) => state = state.copyWith(cultureResultOther: value);
  void setPathogen(String value) => state = state.copyWith(pathogen: value);
  void setPathogenOther(String value) => state = state.copyWith(pathogenOther: value);
  void setTestedAntibiotic(String value) => state = state.copyWith(testedAntibiotic: value);
  void setAstResult(String value) => state = state.copyWith(astResult: value);

  // --- Prescriptions ---

  void setAntibioticPrescribed(bool value) => state = state.copyWith(antibioticPrescribed: value);

  void addPrescription() {
    state = state.copyWith(prescriptions: [...state.prescriptions, const PrescriptionDraft()]);
  }

  void updatePrescription(int index, PrescriptionDraft draft) {
    final list = [...state.prescriptions];
    if (index < 0 || index >= list.length) return;
    list[index] = draft;
    state = state.copyWith(prescriptions: list);
  }

  void removePrescription(int index) {
    final list = [...state.prescriptions]..removeAt(index);
    state = state.copyWith(prescriptions: list);
  }

  // --- Submit ---

  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    final api = ref.read(apiClientProvider);
    final request = state.buildRequest();

    try {
      await api.createReport(request);
      state = state.copyWith(
        isBusy: false,
        isSubmitted: true,
        submittedSummary: 'Report recorded.',
      );
    } on DuplicatePatientException catch (e) {
      // A conflict is a decision for the clinician, never an automatic retry.
      final candidates = e.candidates
          .map((c) => PatientMatchCandidate.fromJson(c as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        isBusy: false,
        nearMatches: candidates,
        errorMessage: e.message,
      );
    } on ApiException catch (e) {
      // Keep form data intact so the clinician doesn't lose their work.
      state = state.copyWith(isBusy: false, errorMessage: e.message);
    } on NetworkException catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: e.message);
    }
  }

  void submitAnother() {
    state = const SubmitReportState();
  }
}
