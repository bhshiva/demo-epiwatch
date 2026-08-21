import 'package:flutter/material.dart';
import '../models/surveillance_demo_models.dart';
import '../services/health_authority_demo_data.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Illustrative cluster detection -- the real version of this is graph-ML
/// community detection over the strain/isolate/facility graph in Neo4j,
/// deliberately deferred (see ML_PLAN.md section 4d, kept local/
/// uncommitted, and the manual strain-tagging already live in lab.py's
/// POST /lab/strains). What's shown here is illustrative demo output, not
/// an algorithm's real result.
class GeographicClustersScreen extends StatelessWidget {
  const GeographicClustersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clusters = HealthAuthorityDemoData.geographicClusters;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Geographic Clusters',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusMonitoring.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ILLUSTRATIVE — SEE ML_PLAN.MD',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.statusMonitoring)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const MutedText(
                'Facility clusters that share a strain or a rise pattern -- manually tagged '
                'today (Lab > Culture & AST > strain link), automated clustering not built yet.'),
            const SizedBox(height: 22),
            if (clusters.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: MutedText('No clusters flagged.')),
              )
            else
              for (final cluster in clusters) _ClusterDetailCard(cluster: cluster),
          ],
        ),
      ),
    );
  }
}

class _ClusterDetailCard extends StatelessWidget {
  final GeographicCluster cluster;
  const _ClusterDetailCard({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final increase = cluster.reportingIncreasePercent;
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.statusCritical,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(cluster.priority,
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Detected: ${cluster.detectedAt}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Confidence: ${cluster.confidencePercent}%',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(cluster.title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final tiles = [
              ('${cluster.facilityCount}', 'Facilities', AppColors.textPrimary, false),
              (
                '${increase >= 0 ? '↑' : '↓'}${increase.abs().toStringAsFixed(0)}%',
                'Reporting Increase',
                AppColors.statusCritical,
                true
              ),
              ('${cluster.affectedDistricts}', 'Affected Districts', AppColors.textPrimary, false),
              ('${cluster.signalDurationDays} days', 'Signal Duration', AppColors.textPrimary, false),
            ];
            final perRow = constraints.maxWidth >= 600 ? 4 : 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: (constraints.maxWidth - 14 * (perRow - 1)) / perRow,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.$4 ? AppColors.statusCritical.withValues(alpha: 0.08) : AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: t.$4 ? Border.all(color: AppColors.statusCritical.withValues(alpha: 0.3)) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.$1,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: t.$3)),
                          const SizedBox(height: 2),
                          MutedText(t.$2),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Expected: ',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              Text('${cluster.expectedPerWeek}/wk',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(width: 20),
              Text('Current: ', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              Text('${cluster.currentPerWeek}/wk',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.statusCritical)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.accentTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                      children: [
                        const TextSpan(
                            text: 'Recommended: ',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextSpan(text: cluster.recommendation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
