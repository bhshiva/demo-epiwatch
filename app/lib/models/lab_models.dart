/// Lab-side models: the isolate/AST worklist and the culture & susceptibility
/// submission shape.
///
/// Mirrors `LabSummary`, `IsolateOut` and `IsolateCreate` from the backend
/// contract (see `lib/services/clinical_catalog.dart` for the coded
/// vocabularies these fields draw from).
class LabSummary {
  final int isolatesToday;
  final int pendingCultures;
  final int mdrIsolatesWeek;
  final double? resistanceRateWeek;

  const LabSummary({
    this.isolatesToday = 0,
    this.pendingCultures = 0,
    this.mdrIsolatesWeek = 0,
    this.resistanceRateWeek,
  });

  static const zero = LabSummary();

  factory LabSummary.fromJson(Map<String, dynamic> json) => LabSummary(
        isolatesToday: json['isolates_today'] as int? ?? 0,
        pendingCultures: json['pending_cultures'] as int? ?? 0,
        mdrIsolatesWeek: json['mdr_isolates_week'] as int? ?? 0,
        resistanceRateWeek: (json['resistance_rate_week'] as num?)?.toDouble(),
      );
}

/// One antibiotic susceptibility result attached to an isolate.
class AstResult {
  final String antibiotic;
  final String? antibioticClass;
  final String? astResult;
  final double? micValue;
  final String? micOperator;
  final int? zoneDiameterMm;
  final String? method;

  const AstResult({
    required this.antibiotic,
    this.antibioticClass,
    this.astResult,
    this.micValue,
    this.micOperator,
    this.zoneDiameterMm,
    this.method,
  });

  factory AstResult.fromJson(Map<String, dynamic> json) => AstResult(
        antibiotic: json['antibiotic'] as String,
        antibioticClass: json['antibiotic_class'] as String?,
        astResult: json['ast_result'] as String?,
        micValue: (json['mic_value'] as num?)?.toDouble(),
        micOperator: json['mic_operator'] as String?,
        zoneDiameterMm: json['zone_diameter_mm'] as int?,
        method: json['method'] as String?,
      );
}

/// One recorded culture/isolate, matching `IsolateOut`.
class Isolate {
  final String isolateId;
  final String? reportId;
  final String? accessionNo;
  final String? collectionDate;
  final String? testDate;
  final String? specimenType;
  final String? cultureResult;
  final String? pathogen;
  final String? infectionOrigin;
  final String status;
  final String? notes;
  final String createdAt;
  final List<AstResult> astResults;
  final int resistantCount;
  final int testedCount;
  final bool isMdr;

  const Isolate({
    required this.isolateId,
    this.reportId,
    this.accessionNo,
    this.collectionDate,
    this.testDate,
    this.specimenType,
    this.cultureResult,
    this.pathogen,
    this.infectionOrigin,
    required this.status,
    this.notes,
    required this.createdAt,
    this.astResults = const [],
    this.resistantCount = 0,
    this.testedCount = 0,
    this.isMdr = false,
  });

  factory Isolate.fromJson(Map<String, dynamic> json) => Isolate(
        isolateId: json['isolate_id'] as String,
        reportId: json['report_id'] as String?,
        accessionNo: json['accession_no'] as String?,
        collectionDate: json['collection_date'] as String?,
        testDate: json['test_date'] as String?,
        specimenType: json['specimen_type'] as String?,
        cultureResult: json['culture_result'] as String?,
        pathogen: json['pathogen'] as String?,
        infectionOrigin: json['infection_origin'] as String?,
        status: json['status'] as String? ?? 'pending',
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        astResults: (json['ast_results'] as List<dynamic>? ?? const [])
            .map((e) => AstResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        resistantCount: json['resistant_count'] as int? ?? 0,
        testedCount: json['tested_count'] as int? ?? 0,
        isMdr: json['is_mdr'] as bool? ?? false,
      );

  /// e.g. "2/8 resistant" — a short panel summary for confirmation messages.
  String get panelSummary => '$resistantCount/$testedCount resistant';
}

/// One AST row in a `POST /lab/isolates` request body.
class AstResultInput {
  final String antibiotic;
  final String? antibioticClass;
  final String? astResult;
  final double? micValue;
  final String? micOperator;
  final int? zoneDiameterMm;
  final String? method;

  const AstResultInput({
    required this.antibiotic,
    this.antibioticClass,
    this.astResult,
    this.micValue,
    this.micOperator,
    this.zoneDiameterMm,
    this.method,
  });

  Map<String, dynamic> toJson() => {
        'antibiotic': antibiotic,
        'antibiotic_class': antibioticClass,
        'ast_result': astResult,
        'mic_value': micValue,
        'mic_operator': micOperator,
        'zone_diameter_mm': zoneDiameterMm,
        'method': method,
      };
}

/// The body of `POST /lab/isolates`.
class IsolateCreateRequest {
  final String? reportId;
  final String? patientId;
  final String? accessionNo;
  final String? collectionDate;
  final String? testDate;
  final String? specimenType;
  final String? specimenTypeOther;
  final String? cultureResult;
  final String? cultureResultOther;
  final String? pathogen;
  final String? pathogenOther;
  final String? infectionOrigin;
  final String status;
  final String? notes;
  final List<AstResultInput> astResults;

  const IsolateCreateRequest({
    this.reportId,
    this.patientId,
    this.accessionNo,
    this.collectionDate,
    this.testDate,
    this.specimenType,
    this.specimenTypeOther,
    this.cultureResult,
    this.cultureResultOther,
    this.pathogen,
    this.pathogenOther,
    this.infectionOrigin,
    this.status = 'preliminary',
    this.notes,
    this.astResults = const [],
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'patient_id': patientId,
        'accession_no': accessionNo,
        'collection_date': collectionDate,
        'test_date': testDate,
        'specimen_type': specimenType,
        'specimen_type_other': specimenTypeOther,
        'culture_result': cultureResult,
        'culture_result_other': cultureResultOther,
        'pathogen': pathogen,
        'pathogen_other': pathogenOther,
        'infection_origin': infectionOrigin,
        'status': status,
        'notes': notes,
        'ast_results': astResults.map((a) => a.toJson()).toList(),
      };
}
