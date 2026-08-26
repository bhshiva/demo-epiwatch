import 'package:flutter/material.dart';
import '../models/ingestion_models.dart';
import '../theme/app_colors.dart';

class IntelligenceAuditBanner extends StatelessWidget {
  final IntelligenceAudit audit;
  final VoidCallback? onDismiss;

  const IntelligenceAuditBanner({
    super.key,
    required this.audit,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusIcon, statusLabel) = _resolveStatusTheme();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Plausibility: ${audit.plausibilityScore}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        audit.summary,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
          ),

          // MDR Alert if detected
          if (audit.mdrFlag)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusElevated.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.statusElevated.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.statusElevated, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Multi-Drug Resistant (MDR) pattern detected (>= 3 antimicrobial classes resistant).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusElevated,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Detailed Findings
          if (audit.findings.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INTELLIGENCE & CONSISTENCY AUDIT DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...audit.findings.map((f) => _buildFindingRow(f)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFindingRow(IntelligenceFinding finding) {
    Color itemColor;
    IconData itemIcon;

    switch (finding.severity) {
      case 'CRITICAL':
        itemColor = AppColors.statusCritical;
        itemIcon = Icons.error_outline;
        break;
      case 'WARNING':
        itemColor = AppColors.statusMonitoring;
        itemIcon = Icons.warning_amber_rounded;
        break;
      default:
        itemColor = AppColors.accentBlue;
        itemIcon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(itemIcon, color: itemColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: itemColor,
                  ),
                ),
                Text(
                  finding.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (finding.suggestedAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Action: ${finding.suggestedAction}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
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

  (Color, Color, IconData, String) _resolveStatusTheme() {
    switch (audit.status) {
      case 'CRITICAL_ANOMALY':
        return (
          AppColors.statusCritical,
          const Color(0xFFFEF2F2),
          Icons.gpp_bad_rounded,
          'Critical Contradiction / Potential False Data',
        );
      case 'WARNING':
        return (
          AppColors.statusMonitoring,
          const Color(0xFFFFFBEB),
          Icons.gpp_maybe_rounded,
          'Clinical Advisory Warnings',
        );
      default:
        return (
          AppColors.statusNormal,
          const Color(0xFFF0FDF4),
          Icons.gpp_good_rounded,
          'Clinical Intelligence Verified Plausible',
        );
    }
  }
}
