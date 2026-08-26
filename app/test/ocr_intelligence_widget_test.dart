import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epiwatch/models/ingestion_models.dart';
import 'package:epiwatch/widgets/intelligence_audit_banner.dart';

void main() {
  group('IntelligenceAuditBanner Widget Tests', () {
    testWidgets('renders Valid audit state cleanly', (tester) async {
      const audit = IntelligenceAudit(
        plausibilityScore: 100,
        status: 'VALID',
        isValid: true,
        summary: 'Clinical intelligence verified plausible.',
        findings: [],
        mdrFlag: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntelligenceAuditBanner(audit: audit),
          ),
        ),
      );

      expect(find.text('Clinical Intelligence Verified Plausible'), findsOneWidget);
      expect(find.text('Plausibility: 100%'), findsOneWidget);
      expect(find.text('Clinical intelligence verified plausible.'), findsOneWidget);
    });

    testWidgets('renders Critical Anomaly state with findings and MDR alert', (tester) async {
      const finding = IntelligenceFinding(
        category: 'intrinsic_resistance',
        severity: 'CRITICAL',
        title: 'Intrinsic Resistance Violation (Ampicillin)',
        description: 'Klebsiella pneumoniae is intrinsically resistant to Ampicillin.',
        suggestedAction: 'Change Ampicillin to Resistant or Not tested.',
      );

      const audit = IntelligenceAudit(
        plausibilityScore: 40,
        status: 'CRITICAL_ANOMALY',
        isValid: false,
        summary: 'Detected critical contradictions in microbiology AST data.',
        findings: [finding],
        mdrFlag: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntelligenceAuditBanner(audit: audit),
          ),
        ),
      );

      expect(find.text('Critical Contradiction / Potential False Data'), findsOneWidget);
      expect(find.text('Plausibility: 40%'), findsOneWidget);
      expect(find.text('Intrinsic Resistance Violation (Ampicillin)'), findsOneWidget);
      expect(find.text('Multi-Drug Resistant (MDR) pattern detected (>= 3 antimicrobial classes resistant).'), findsOneWidget);
      expect(find.text('Action: Change Ampicillin to Resistant or Not tested.'), findsOneWidget);
    });
  });
}
