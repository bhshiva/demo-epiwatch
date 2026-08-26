class Prescription {
  final String drugName;
  final String? dosage;
  final String? duration;

  const Prescription({required this.drugName, this.dosage, this.duration});

  Map<String, dynamic> toJson() => {
        'drug_name': drugName,
        'dosage': dosage,
        'duration': duration,
      };
}

class LabResultInput {
  final String? testDate;
  final String? specimenType;
  final String? specimenTypeOther;
  final String? cultureResult;
  final String? cultureResultOther;
  final String? pathogen;
  final String? pathogenOther;
  final String? antibiotic;
  final String? astResult;

  const LabResultInput({
    this.testDate,
    this.specimenType,
    this.specimenTypeOther,
    this.cultureResult,
    this.cultureResultOther,
    this.pathogen,
    this.pathogenOther,
    this.antibiotic,
    this.astResult,
  });

  Map<String, dynamic> toJson() => {
        'test_date': testDate,
        'specimen_type': specimenType,
        'specimen_type_other': specimenTypeOther,
        'culture_result': cultureResult,
        'culture_result_other': cultureResultOther,
        'pathogen': pathogen,
        'pathogen_other': pathogenOther,
        'antibiotic': antibiotic,
        'ast_result': astResult,
      };
}

class PatientIdentityInput {
  final String fullName;
  final String? dateOfBirth;
  final int? exactAge;
  final String? contactNumber;
  final String? facilityMrn;
  final String? abhaId;
  final String? district;

  const PatientIdentityInput({
    required this.fullName,
    this.dateOfBirth,
    this.exactAge,
    this.contactNumber,
    this.facilityMrn,
    this.abhaId,
    this.district,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'exact_age': exactAge,
        'contact_number': contactNumber,
        'facility_mrn': facilityMrn,
        'abha_id': abhaId,
        'district': district,
      };
}

/// The body of POST /reports.
///
/// Supply [patientId] to continue an existing patient's record, or
/// [patientIdentity] to register a new one. Sending [patientId] is what
/// prevents a fresh duplicate patient row per visit.
class ReportCreateRequest {
  final String? patientId;
  final PatientIdentityInput? patientIdentity;
  final int? patientExactAge;
  final bool confirmedNew;
  final String patientAgeGroup;
  final String patientSex;
  final String patientDistrict;
  final String reportDate;
  /// BCP-47 language code of the UI at submission time (e.g. "hi", "mr",
  /// "auto"). Forwarded to the server so GoogleTranslator uses the exact
  /// source language rather than relying on auto-detect.
  final String sourceLanguage;
  final String? complaints;
  final String? medicalHistory;
  final List<String> symptoms;
  final String? diagnosis;
  final String? diagnosisStatus;
  final String? treatment;
  final String? infectionSyndrome;
  final String? infectionSyndromeOther;
  final String? infectionOrigin;
  final String? patientOutcome;
  final String? patientOutcomeOther;
  final List<Prescription> prescriptions;
  final LabResultInput? labResult;

  const ReportCreateRequest({
    this.patientId,
    this.patientIdentity,
    this.patientExactAge,
    this.confirmedNew = false,
    required this.patientAgeGroup,
    required this.patientSex,
    required this.patientDistrict,
    required this.reportDate,
    this.sourceLanguage = 'auto',
    this.complaints,
    this.medicalHistory,
    this.symptoms = const [],
    this.diagnosis,
    this.diagnosisStatus,
    this.treatment,
    this.infectionSyndrome,
    this.infectionSyndromeOther,
    this.infectionOrigin,
    this.patientOutcome,
    this.patientOutcomeOther,
    this.prescriptions = const [],
    this.labResult,
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'patient_identity': patientIdentity?.toJson(),
        'patient_exact_age': patientExactAge,
        'confirmed_new': confirmedNew,
        'patient_age_group': patientAgeGroup,
        'patient_sex': patientSex,
        'patient_district': patientDistrict,
        'report_date': reportDate,
        'source_language': sourceLanguage,
        'complaints': complaints,
        'medical_history': medicalHistory,
        'symptoms': symptoms,
        'diagnosis': diagnosis,
        'diagnosis_status': diagnosisStatus,
        'treatment': treatment,
        'infection_syndrome': infectionSyndrome,
        'infection_syndrome_other': infectionSyndromeOther,
        'infection_origin': infectionOrigin,
        'patient_outcome': patientOutcome,
        'patient_outcome_other': patientOutcomeOther,
        'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
        'lab_result': labResult?.toJson(),
      };
}
