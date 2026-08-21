import 'package:flutter/material.dart';
import '../services/national_stats_data.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Real, sourced government/ICMR statistics -- see NationalStatsData's doc
/// comment for sources and as-of dates. Deliberately, visibly separate from
/// this app's own (simulated/demo) pilot data, so nobody mistakes one for
/// the other.
class NationalStatisticsScreen extends StatelessWidget {
  const NationalStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('National Statistics',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const MutedText(
                'Sourced government and ICMR figures that ground this platform\'s design -- '
                'shown alongside clearly labeled simulated pilot data so evaluators can tell '
                'real national baselines apart from demo output.'),
            const SizedBox(height: 22),
            _SourcedSectionCard(
              icon: Icons.local_hospital_outlined,
              section: NationalStatsData.infrastructure,
            ),
            const SizedBox(height: 18),
            _FacilityBreakdownCard(),
            const SizedBox(height: 18),
            _SourcedSectionCard(
              icon: Icons.verified_outlined,
              section: NationalStatsData.digitalHealth,
            ),
            const SizedBox(height: 18),
            _SourcedSectionCard(
              icon: Icons.science_outlined,
              section: NationalStatsData.amrSnapshot,
            ),
            const SizedBox(height: 18),
            _SourcedSectionCard(
              icon: Icons.bug_report_outlined,
              section: NationalStatsData.vectorBorne,
            ),
            const SizedBox(height: 18),
            const _PilotSnapshotCard(),
          ],
        ),
      ),
    );
  }
}

class _SourcedSectionCard extends StatelessWidget {
  final IconData icon;
  final SourcedSection section;
  const _SourcedSectionCard({required this.icon, required this.section});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accentTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(section.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 13, color: AppColors.accentTeal),
              const SizedBox(width: 5),
              Expanded(
                child: Text(section.source,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 700 ? section.stats.length.clamp(1, 3) : 1;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final stat in section.stats)
                  SizedBox(
                    width: (constraints.maxWidth - 14 * (perRow - 1)) / perRow,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stat.label.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Text(stat.value,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          if (stat.detail != null) ...[
                            const SizedBox(height: 4),
                            Text(stat.detail!,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
          if (section.footnote != null) ...[
            const SizedBox(height: 12),
            MutedText(section.footnote!),
          ],
        ],
      ),
    );
  }
}

class _FacilityBreakdownCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final maxValue = NationalStatsData.facilityBreakdown
        .map((s) => int.parse(s.value.replaceAll(',', '')))
        .reduce((a, b) => a > b ? a : b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Facility Type Breakdown'),
          const SizedBox(height: 4),
          const MutedText('MoHFW — Health Dynamics of India 2022-23, as of 2023-03-31'),
          const SizedBox(height: 16),
          for (final stat in NationalStatsData.facilityBreakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: Text(stat.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor:
                            int.parse(stat.value.replaceAll(',', '')) / maxValue,
                        child: Container(
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.chartBlue,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(stat.value,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PilotSnapshotCard extends StatelessWidget {
  const _PilotSnapshotCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              const Text('Platform Pilot Snapshot',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF78350F))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('⚠ Simulated data for demonstration — not a live national feed',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          ),
          const SizedBox(height: 12),
          const Text(
            'This is a hackathon prototype: the counts elsewhere in this app (facilities '
            'reporting, reports today, etc.) come from a handful of seeded test accounts, '
            'not a national rollout. The real infrastructure and resistance figures above '
            'are what this platform is designed to eventually operate against.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF78350F)),
          ),
        ],
      ),
    );
  }
}
