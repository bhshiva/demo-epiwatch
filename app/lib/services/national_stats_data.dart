/// Real, sourced government/ICMR statistics -- hand-researched and cited,
/// not derived from this app's own data (contrast with
/// HealthAuthorityDemoData, which is illustrative-only and must never be
/// confused with this). Every figure here carries its source and
/// as-of date in the object itself so the UI can render both, matching
/// how the reference design keeps real national baselines visibly
/// distinct from simulated pilot output.
///
/// Sources (fetched 2026-08-22, figures may move -- re-verify before
/// relying on this for anything beyond illustrating the page):
/// - MoHFW, "Health Dynamics of India (Infrastructure and Human
///   Resources) 2022-23", as of 2023-03-31.
/// - ABDM/NHA, ABHA + Health Facility Registry counts, as of 2025-07-28.
/// - ICMR AMRSN, 7th Annual Report (Jan-Dec 2023), 99,492 isolates.
/// - NCVBDC, dengue 2023 and malaria 2024 situation reports.
library;

class SourcedStat {
  final String label;
  final String value;
  final String? detail;

  const SourcedStat({required this.label, required this.value, this.detail});
}

class SourcedSection {
  final String title;
  final String source;
  final List<SourcedStat> stats;
  final String? footnote;

  const SourcedSection({
    required this.title,
    required this.source,
    required this.stats,
    this.footnote,
  });
}

abstract final class NationalStatsData {
  static const infrastructure = SourcedSection(
    title: "India's Public Health Infrastructure",
    source: 'Ministry of Health & Family Welfare — Health Dynamics of India '
        '(Infrastructure and Human Resources) 2022-23 · as of 2023-03-31',
    stats: [
      SourcedStat(label: 'Total Addressable Facilities', value: '2.1L', detail: 'SCs + PHCs + CHCs + SDHs + DHs'),
      SourcedStat(label: 'Hospital Beds (PHC-DH + Medical Colleges)', value: '8.19L', detail: '8,18,661 beds'),
      SourcedStat(label: 'Sub-Centres', value: '1.70L', detail: '1,69,615'),
    ],
  );

  static const facilityBreakdown = [
    SourcedStat(label: 'Sub-Centres', value: '1,69,615'),
    SourcedStat(label: 'Primary Health Centres', value: '31,882'),
    SourcedStat(label: 'Community Health Centres', value: '6,359'),
    SourcedStat(label: 'Sub-Divisional / District Hospitals', value: '1,340'),
    SourcedStat(label: 'District Hospitals', value: '714'),
    SourcedStat(label: 'Medical Colleges', value: '362'),
  ];

  static const digitalHealth = SourcedSection(
    title: 'Digital Health Adoption (ABDM)',
    source: 'National Health Authority — ABDM dashboard · as of 2025-07-28',
    stats: [
      SourcedStat(label: 'ABHA Health Accounts Created', value: '79.71 Cr'),
      SourcedStat(label: 'Facilities Registered on HFR', value: '4.17 L'),
    ],
  );

  /// %resistant or %reduced-susceptibility, ICMR AMRSN 7th Annual Report
  /// (Jan-Dec 2023, 99,492 isolates). Percentages below are as directly
  /// reported; "reduced susceptibility" and "resistance" are the report's
  /// own framing per pathogen/drug, not normalized to one metric.
  static const amrSnapshot = SourcedSection(
    title: 'AMR Trends — ICMR AMRSN 2023',
    source: 'ICMR AMRSN — 7th Annual Report (Jan-Dec 2023), 99,492 isolates nationwide',
    stats: [
      // These three are SUSCEPTIBILITY figures (falling over time), not
      // resistance figures -- reported as ICMR stated them, not inverted,
      // since the source snippet doesn't give the S/I/R split needed to
      // compute a resistance percentage correctly.
      SourcedStat(
        label: 'E. coli susceptibility — piperacillin-tazobactam',
        value: '42.4%',
        detail: 'down from 56.8% in 2017',
      ),
      SourcedStat(
        label: 'K. pneumoniae susceptibility — meropenem',
        value: '37.6%',
        detail: 'down from 48% in 2017',
      ),
      SourcedStat(
        label: 'K. pneumoniae susceptibility — imipenem',
        value: '35.6%',
        detail: 'down from 58.5% in 2017',
      ),
      // These two ARE reported directly as resistance percentages.
      SourcedStat(
        label: 'Acinetobacter baumannii — carbapenem resistance',
        value: '88%',
        detail: '2023',
      ),
      SourcedStat(
        label: 'Salmonella Typhi — fluoroquinolone resistance',
        value: '>95%',
        detail: '2023',
      ),
    ],
    footnote: 'Figures are as directly reported by ICMR AMRSN; this platform does not '
        'independently verify or recompute them. The first three rows are '
        'susceptibility (falling), the last two are resistance (rising) -- read '
        'the row label, not just the number.',
  );

  static const vectorBorne = SourcedSection(
    title: 'Vector-Borne Disease Burden',
    source: 'National Center for Vector Borne Diseases Control (NCVBDC), MoHFW',
    stats: [
      SourcedStat(label: 'Dengue Cases (2023)', value: '2,89,235', detail: '485 deaths'),
      SourcedStat(label: 'Malaria API (2024)', value: '0.18', detail: 'per 1,000, down from 3.29 in 1995 (−94.5%)'),
      SourcedStat(
        label: 'P. falciparum share of malaria',
        value: '60.07%',
        detail: 'up from 39% in 1995 — remaining cases concentrating in high-risk pockets',
      ),
    ],
  );
}
