import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surveillance_models.dart';
import '../models/surveillance_demo_models.dart';
import '../state/surveillance_dashboard.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Alerts screen that connects with the real-time ML risk engine output.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String? _selectedId;
  final Map<String, String> _localStatuses = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surveillanceDashboardProvider);
    final facilities = state.facilities;

    // Map backend Alert model to UI SurveillanceAlert model
    final alerts = state.alerts.map((a) {
      final alertId = "${a.facilityId}_${a.organism}";
      final fac = facilities.firstWhere(
        (f) => f.facilityId == a.facilityId,
        orElse: () => FacilityGeo(
          facilityId: a.facilityId,
          name: 'Facility ${a.facilityId.substring(0, math.min(8, a.facilityId.length))}',
          district: 'Unknown',
          state: 'Unknown',
          recentCaseCount: 0,
        ),
      );
      
      final severity = a.alertLevel.toUpperCase();
      final status = _localStatuses[alertId] ?? 'Needs Review';
      
      return SurveillanceAlert(
        id: alertId,
        severity: severity == 'WATCH' ? 'MEDIUM' : (severity == 'ELEVATED' ? 'HIGH' : severity),
        title: '${a.organism ?? 'Unknown Pathogen'} Anomaly',
        region: '${fac.name} (${fac.district}, ${fac.state})',
        detectedAgo: a.date ?? 'recently',
        summary: 'Isolation Forest detected a composite risk score of ${a.compositeRiskScore.toStringAsFixed(2)} for ${a.organism ?? 'pathogen'} at ${fac.name}.',
        confidencePercent: (a.compositeRiskScore * 100).toInt().clamp(0, 100),
        status: status,
        contributingSites: 1,
      );
    }).toList();

    final matching = alerts.where((a) => a.id == _selectedId);
    final selected = matching.isNotEmpty ? matching.first : (alerts.isNotEmpty ? alerts.first : null);
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    final counts = <String, int>{
      'CRITICAL': 0,
      'HIGH': 0,
      'MEDIUM': 0,
      'RESOLVED': 0,
    };
    for (final a in alerts) {
      counts[a.severity] = (counts[a.severity] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Alerts',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusMonitoring.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ML ALERTS',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.statusMonitoring)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const MutedText('Review, prioritize and manage emerging surveillance signals.'),
            const SizedBox(height: 22),
            _SeverityRow(counts: counts),
            const SizedBox(height: 18),
            if (alerts.isEmpty)
              const SectionCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: MutedText('No active alerts detected by the pipeline.')),
                ),
              )
            else if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _AlertList(
                        alerts: alerts,
                        selectedId: selected?.id,
                        onSelect: (id) => setState(() => _selectedId = id),
                        onAssign: (id) => setState(() => _localStatuses[id] = 'Assigned'),
                        onAcknowledge: (id) => setState(() => _localStatuses[id] = 'Acknowledged'),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: _AlertDetail(alert: selected)),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _AlertList(
                    alerts: alerts,
                    selectedId: selected?.id,
                    onSelect: (id) => setState(() => _selectedId = id),
                    onAssign: (id) => setState(() => _localStatuses[id] = 'Assigned'),
                    onAcknowledge: (id) => setState(() => _localStatuses[id] = 'Acknowledged'),
                  ),
                  const SizedBox(height: 18),
                  _AlertDetail(alert: selected),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  final Map<String, int> counts;
  const _SeverityRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('CRITICAL', AppColors.statusCritical),
      ('HIGH', AppColors.statusElevated),
      ('MEDIUM', AppColors.statusMonitoring),
      ('RESOLVED', AppColors.statusNormal),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 700 ? 4 : 2;
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
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.$2.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: t.$2, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.$1,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ),
                    Text('${counts[t.$1] ?? 0}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: t.$2)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _AlertList extends StatelessWidget {
  final List<SurveillanceAlert> alerts;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onAssign;
  final ValueChanged<String> onAcknowledge;

  const _AlertList({
    required this.alerts,
    required this.selectedId,
    required this.onSelect,
    required this.onAssign,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final alert in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => onSelect(alert.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: alert.id == selectedId
                        ? _severityColor(alert.severity)
                        : AppColors.border,
                    width: alert.id == selectedId ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SeverityChip(severity: alert.severity),
                        const SizedBox(width: 10),
                        Text('Detected ${alert.detectedAgo}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(alert.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      MutedText(alert.region),
                    ]),
                    const SizedBox(height: 6),
                    Text('"${alert.summary}"',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Text('CONFIDENCE',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Text('${alert.confidencePercent}%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: alert.confidencePercent / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: _severityColor(alert.severity),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.bgTertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('STATUS: ${alert.status.toUpperCase()}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => onSelect(alert.id), child: const Text('Open')),
                        const SizedBox(width: 4),
                        TextButton(onPressed: () => onAssign(alert.id), child: const Text('Assign')),
                        const SizedBox(width: 4),
                        FilledButton(onPressed: () => onAcknowledge(alert.id), child: const Text('Ack')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertDetail extends StatelessWidget {
  final SurveillanceAlert? alert;
  const _AlertDetail({required this.alert});

  @override
  Widget build(BuildContext context) {
    final a = alert;
    if (a == null) {
      return const SectionCard(
        child: Center(child: MutedText('Select an alert to see details.')),
      );
    }
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${a.id}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(a.title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            MutedText(a.region),
          ]),
          const Divider(height: 28),
          const SectionTitle('Signal Summary'),
          const SizedBox(height: 8),
          Text(
            'Syndromic surveillance system has detected a statistically significant '
            'anomaly in ${a.title.toLowerCase()} presentations across multiple sentinel '
            'sites in ${a.region} over the past 48 hours.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Spatial Distribution'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text('${a.contributingSites} Sites',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                const MutedText('contributing data in district'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(String severity) => switch (severity) {
      'CRITICAL' => AppColors.statusCritical,
      'HIGH' => AppColors.statusElevated,
      'MEDIUM' => AppColors.statusMonitoring,
      _ => AppColors.statusNormal,
    };

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(severity,
          style: const TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Colors.white)),
    );
  }
}
