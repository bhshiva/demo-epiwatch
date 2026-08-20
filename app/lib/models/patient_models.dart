/// A patient match, with enough context to pick the right person.
class PatientSearchResult {
  final String patientId;
  final String fullName;
  final int? exactAge;
  final String ageGroup;
  final String sex;
  final String district;
  final String? facilityMrn;
  final String? abhaId;
  final int reportCount;
  final String? lastVisit;

  const PatientSearchResult({
    required this.patientId,
    required this.fullName,
    this.exactAge,
    required this.ageGroup,
    required this.sex,
    required this.district,
    this.facilityMrn,
    this.abhaId,
    required this.reportCount,
    this.lastVisit,
  });

  factory PatientSearchResult.fromJson(Map<String, dynamic> json) => PatientSearchResult(
        patientId: json['patient_id'] as String,
        fullName: json['full_name'] as String,
        exactAge: json['exact_age'] as int?,
        ageGroup: json['age_group'] as String,
        sex: json['sex'] as String,
        district: json['district'] as String,
        facilityMrn: json['facility_mrn'] as String?,
        abhaId: json['abha_id'] as String?,
        reportCount: json['report_count'] as int? ?? 0,
        lastVisit: json['last_visit'] as String?,
      );

  String get summary {
    final age = exactAge != null ? '${exactAge}y' : ageGroup;
    final mrn = (facilityMrn == null || facilityMrn!.isEmpty) ? '' : ' · $facilityMrn';
    return '$age · $sex · $district$mrn';
  }

  String get visitSummary {
    if (reportCount == 0) return 'No previous reports';
    final plural = reportCount == 1 ? '' : 's';
    final visit = lastVisit != null ? ' · last $lastVisit' : '';
    return '$reportCount report$plural$visit';
  }
}

/// A candidate returned by duplicate-patient matching, with the score and
/// signals that justify surfacing it rather than silently creating a new
/// patient record.
class PatientMatchCandidate extends PatientSearchResult {
  final double score;
  final String confidence; // "auto" | "review" | "weak"
  final String matchType; // "exact_abha" | "exact_mrn" | "probabilistic"
  final List<String> matchedOn;

  const PatientMatchCandidate({
    required super.patientId,
    required super.fullName,
    super.exactAge,
    required super.ageGroup,
    required super.sex,
    required super.district,
    super.facilityMrn,
    super.abhaId,
    required super.reportCount,
    super.lastVisit,
    required this.score,
    required this.confidence,
    required this.matchType,
    required this.matchedOn,
  });

  factory PatientMatchCandidate.fromJson(Map<String, dynamic> json) => PatientMatchCandidate(
        patientId: json['patient_id'] as String,
        fullName: json['full_name'] as String,
        exactAge: json['exact_age'] as int?,
        ageGroup: json['age_group'] as String,
        sex: json['sex'] as String,
        district: json['district'] as String,
        facilityMrn: json['facility_mrn'] as String?,
        abhaId: json['abha_id'] as String?,
        reportCount: json['report_count'] as int? ?? 0,
        lastVisit: json['last_visit'] as String?,
        score: (json['score'] as num).toDouble(),
        confidence: json['confidence'] as String,
        matchType: json['match_type'] as String,
        matchedOn: (json['matched_on'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// One prior visit for a patient.
class PatientHistoryEntry {
  final String reportId;
  final String reportDate;
  final String? diagnosis;
  final String? diagnosisStatus;
  final String? complaints;
  final String? pathogen;
  final String? cultureResult;
  final String? astResult;

  const PatientHistoryEntry({
    required this.reportId,
    required this.reportDate,
    this.diagnosis,
    this.diagnosisStatus,
    this.complaints,
    this.pathogen,
    this.cultureResult,
    this.astResult,
  });

  factory PatientHistoryEntry.fromJson(Map<String, dynamic> json) => PatientHistoryEntry(
        reportId: json['report_id'] as String,
        reportDate: json['report_date'] as String,
        diagnosis: json['diagnosis'] as String?,
        diagnosisStatus: json['diagnosis_status'] as String?,
        complaints: json['complaints'] as String?,
        pathogen: json['pathogen'] as String?,
        cultureResult: json['culture_result'] as String?,
        astResult: json['ast_result'] as String?,
      );

  // A "No growth" culture is a real finding, so a lab row with no organism
  // identified must still render rather than appearing blank.
  bool get hasLabResult =>
      (pathogen != null && pathogen!.isNotEmpty) ||
      (cultureResult != null && cultureResult!.isNotEmpty);
}

/// Result of checking an ABHA number.
///
/// `isValid` reflects the offline format/checksum check, which always runs.
/// `verified` is only true when the national registry confirmed the account,
/// so the UI can distinguish "looks right" from "confirmed to exist".
class AbhaVerifyResult {
  final String? abhaNumber;
  final bool isValid;
  final bool verified;
  final String? name;
  final String? gender;
  final String? dateOfBirth;
  final String? stateName;

  const AbhaVerifyResult({
    this.abhaNumber,
    required this.isValid,
    this.verified = false,
    this.name,
    this.gender,
    this.dateOfBirth,
    this.stateName,
  });

  factory AbhaVerifyResult.fromJson(Map<String, dynamic> json) => AbhaVerifyResult(
        abhaNumber: json['abha_number'] as String?,
        isValid: json['is_valid'] as bool,
        verified: json['verified'] as bool? ?? false,
        name: json['name'] as String?,
        gender: json['gender'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        stateName: json['state_name'] as String?,
      );
}
