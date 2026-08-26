class IntelligenceFinding {
  final String category;
  final String severity; // "CRITICAL", "WARNING", "INFO"
  final String title;
  final String description;
  final String? field;
  final String? suggestedAction;

  const IntelligenceFinding({
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.field,
    this.suggestedAction,
  });

  factory IntelligenceFinding.fromJson(Map<String, dynamic> json) {
    return IntelligenceFinding(
      category: json['category'] as String? ?? 'general',
      severity: json['severity'] as String? ?? 'INFO',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      field: json['field'] as String?,
      suggestedAction: json['suggested_action'] as String?,
    );
  }
}

class IntelligenceAudit {
  final int plausibilityScore;
  final String status; // "VALID", "WARNING", "CRITICAL_ANOMALY"
  final bool isValid;
  final String summary;
  final List<IntelligenceFinding> findings;
  final bool mdrFlag;

  const IntelligenceAudit({
    required this.plausibilityScore,
    required this.status,
    required this.isValid,
    required this.summary,
    required this.findings,
    required this.mdrFlag,
  });

  factory IntelligenceAudit.fromJson(Map<String, dynamic> json) {
    final rawFindings = json['findings'] as List<dynamic>? ?? [];
    return IntelligenceAudit(
      plausibilityScore: json['plausibility_score'] as int? ?? 100,
      status: json['status'] as String? ?? 'VALID',
      isValid: json['is_valid'] as bool? ?? true,
      summary: json['summary'] as String? ?? '',
      findings: rawFindings.map((f) {
        if (f is Map<String, dynamic>) {
          return IntelligenceFinding.fromJson(f);
        } else if (f is Map) {
          return IntelligenceFinding.fromJson(Map<String, dynamic>.from(f));
        } else if (f is String) {
          return IntelligenceFinding(
            category: 'notice',
            severity: 'INFO',
            title: 'Notice',
            description: f,
          );
        }
        return IntelligenceFinding(
          category: 'general',
          severity: 'INFO',
          title: 'Info',
          description: f.toString(),
        );
      }).toList(),
      mdrFlag: json['mdr_flag'] as bool? ?? false,
    );
  }
}

class OcrParseResult {
  final String rawText;
  final Map<String, dynamic> extracted;
  final IntelligenceAudit intelligenceAudit;

  const OcrParseResult({
    required this.rawText,
    required this.extracted,
    required this.intelligenceAudit,
  });

  factory OcrParseResult.fromJson(Map<String, dynamic> json) {
    return OcrParseResult(
      rawText: json['raw_text'] as String? ?? '',
      extracted: (json['extracted'] as Map<String, dynamic>?) ?? {},
      intelligenceAudit: IntelligenceAudit.fromJson(
        (json['intelligence_audit'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}
