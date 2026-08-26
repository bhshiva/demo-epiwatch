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
  String _filterSeverity = 'ALL';
  final Map<String, String> _localStatuses = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surveillanceDashboardProvider);
    final facilities = state.facilities;

    // Map backend Alert model to UI SurveillanceAlert model
    final allAlerts = state.alerts.map((a) {
      final alertId = "${a.facilityId}_${a.organism}";
      final fac = facilities.firstWhere(
        (f) => f.facilityId == a.facilityId,
        orElse: () => FacilityGeo(
          facilityId: a.facilityId,
          name: 'Facility ${a.facilityId.substring(0, math.min(8, a.facilityId.length))}',
          district: 'Pune',
          state: 'Maharashtra',
          recentCaseCount: 0,
        ),
      );

      final severity = a.alertLevel.toUpperCase();
      final status = _localStatuses[alertId] ?? 'Needs Review';

      return SurveillanceAlert(
        id: alertId,
        severity: status == 'Resolved'
            ? 'RESOLVED'
            : (severity == 'WATCH' ? 'MEDIUM' : (severity == 'ELEVATED' ? 'HIGH' : severity)),
        title: '${a.organism ?? 'Unknown Pathogen'} Anomaly',
        region: '${fac.name} (${fac.district}, ${fac.state})',
        detectedAgo: a.date ?? 'recently',
        summary: 'Isolation Forest detected a composite risk score of ${a.compositeRiskScore.toStringAsFixed(2)} for ${a.organism ?? 'pathogen'} at ${fac.name}.',
        confidencePercent: (a.compositeRiskScore * 100).toInt().clamp(0, 100),
        status: status,
        contributingSites: 1,
      );
    }).toList();

    // Fallback seed alerts if state alerts are empty
    final alerts = allAlerts.isNotEmpty
        ? allAlerts
        : [
            SurveillanceAlert(
              id: 'ALT-ILI01',
              severity: _localStatuses['ALT-ILI01'] == 'Resolved' ? 'RESOLVED' : 'CRITICAL',
              title: 'Respiratory Illness Anomaly',
              region: 'City General Hospital (Pune, Maharashtra)',
              detectedAgo: '16 Aug 2026, 14:32',
              summary: 'Isolation Forest flagged a 38% reporting increase across acute respiratory syndrome presentations.',
              confidencePercent: 92,
              status: _localStatuses['ALT-ILI01'] ?? 'Needs Review',
              contributingSites: 4,
            ),
            SurveillanceAlert(
              id: 'ALT-ECO02',
              severity: _localStatuses['ALT-ECO02'] == 'Resolved' ? 'RESOLVED' : 'HIGH',
              title: 'Reduced Susceptibility — E. coli',
              region: 'Ruby Hall Sentinel Clinic (Pune, Maharashtra)',
              detectedAgo: '16 Aug 2026, 11:15',
              summary: 'Fluoroquinolone resistance rate elevated to 69% across 13 tested isolates.',
              confidencePercent: 84,
              status: _localStatuses['ALT-ECO02'] ?? 'Needs Review',
              contributingSites: 2,
            ),
            SurveillanceAlert(
              id: 'ALT-KLEB03',
              severity: _localStatuses['ALT-KLEB03'] == 'Resolved' ? 'RESOLVED' : 'HIGH',
              title: 'Klebsiella pneumoniae Cluster',
              region: 'KEM Hospital Parel (Mumbai, Maharashtra)',
              detectedAgo: '15 Aug 2026, 18:40',
              summary: 'Ceftriaxone resistance elevated to 54% with co-occurring MDR markers.',
              confidencePercent: 78,
              status: _localStatuses['ALT-KLEB03'] ?? 'Assigned',
              contributingSites: 3,
            ),
            SurveillanceAlert(
              id: 'ALT-FEV04',
              severity: _localStatuses['ALT-FEV04'] == 'Resolved' ? 'RESOLVED' : 'MEDIUM',
              title: 'Atypical Fever Spike',
              region: 'Dadar Central Clinic (Mumbai, Maharashtra)',
              detectedAgo: '14 Aug 2026, 09:20',
              summary: 'Syndromic presentation uptick with 26 weekly cases reported.',
              confidencePercent: 65,
              status: _localStatuses['ALT-FEV04'] ?? 'Acknowledged',
              contributingSites: 1,
            ),
          ];

    final filteredAlerts = _filterSeverity == 'ALL'
        ? alerts
        : alerts.where((a) => a.severity == _filterSeverity).toList();

    final matching = filteredAlerts.where((a) => a.id == _selectedId);
    final selected = matching.isNotEmpty
        ? matching.first
        : (filteredAlerts.isNotEmpty ? filteredAlerts.first : (alerts.isNotEmpty ? alerts.first : null));
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    final counts = <String, int>{
      'ALL': alerts.length,
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
                  child: const Text('REAL-TIME SURVEILLANCE ENGINE',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.statusMonitoring)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const MutedText('Review, prioritize and manage emerging surveillance signals and outbreak risks.'),
            const SizedBox(height: 22),

            // Severity selector tiles
            _SeverityRow(
              counts: counts,
              selectedFilter: _filterSeverity,
              onFilterSelect: (f) => setState(() => _filterSeverity = f),
            ),
            const SizedBox(height: 18),

            if (filteredAlerts.isEmpty)
              SectionCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 36, color: AppColors.accentTeal),
                        const SizedBox(height: 10),
                        MutedText('No active alerts matching "$_filterSeverity" severity.'),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() => _filterSeverity = 'ALL'),
                          child: const Text('Show All Alerts'),
                        ),
                      ],
                    ),
                  ),
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
                        alerts: filteredAlerts,
                        selectedId: selected?.id,
                        onSelect: (id) => setState(() => _selectedId = id),
                        onAssign: (id) => _showAssignDialog(context, id),
                        onAcknowledge: (id) {
                          setState(() => _localStatuses[id] = 'Acknowledged');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alert status updated to Acknowledged.')),
                          );
                        },
                        onResolve: (id) {
                          setState(() => _localStatuses[id] = 'Resolved');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alert marked as Resolved.')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: _AlertDetail(
                        alert: selected,
                        onInvestigate: (a) => _showInvestigationDialog(context, a),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _AlertList(
                    alerts: filteredAlerts,
                    selectedId: selected?.id,
                    onSelect: (id) => setState(() => _selectedId = id),
                    onAssign: (id) => _showAssignDialog(context, id),
                    onAcknowledge: (id) {
                      setState(() => _localStatuses[id] = 'Acknowledged');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alert status updated to Acknowledged.')),
                      );
                    },
                    onResolve: (id) {
                      setState(() => _localStatuses[id] = 'Resolved');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alert marked as Resolved.')),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _AlertDetail(
                    alert: selected,
                    onInvestigate: (a) => _showInvestigationDialog(context, a),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, String alertId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Alert to Officer'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Designate an epidemiological surveillance officer to investigate this anomaly:'),
            SizedBox(height: 14),
            TextField(
              decoration: InputDecoration(
                labelText: 'Surveillance Officer Name',
                hintText: 'e.g. Dr. Meera Iyer (IDSP Field Unit)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _localStatuses[alertId] = 'Assigned');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert assigned to field officer.')),
              );
            },
            child: const Text('Assign Officer'),
          ),
        ],
      ),
    );
  }

  void _showInvestigationDialog(BuildContext context, SurveillanceAlert alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Initiate Investigation: ${alert.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${alert.region}'),
            const SizedBox(height: 6),
            Text('Confidence: ${alert.confidencePercent}% (${alert.severity})'),
            const SizedBox(height: 14),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Immediate Directives',
                hintText: 'Initiate active case finding & collect confirmatory AST cultures',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _localStatuses[alert.id] = 'Assigned');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rapid response investigation initiated and alert escalated.')),
              );
            },
            child: const Text('Dispatch Team'),
          ),
        ],
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  final Map<String, int> counts;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelect;

  const _SeverityRow({
    required this.counts,
    required this.selectedFilter,
    required this.onFilterSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('ALL', AppColors.accentTeal),
      ('CRITICAL', AppColors.statusCritical),
      ('HIGH', AppColors.statusElevated),
      ('MEDIUM', AppColors.statusMonitoring),
      ('RESOLVED', AppColors.statusNormal),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 850 ? 5 : (constraints.maxWidth >= 500 ? 3 : 2);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final t in tiles)
            SizedBox(
              width: (constraints.maxWidth - 12 * (perRow - 1)) / perRow,
              child: InkWell(
                onTap: () => onFilterSelect(t.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedFilter == t.$1
                        ? t.$2.withValues(alpha: 0.1)
                        : AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedFilter == t.$1 ? t.$2 : AppColors.border,
                      width: selectedFilter == t.$1 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.$1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selectedFilter == t.$1 ? FontWeight.w800 : FontWeight.w600,
                              color: selectedFilter == t.$1 ? t.$2 : AppColors.textSecondary,
                            )),
                      ),
                      Text('${counts[t.$1] ?? 0}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.$2)),
                    ],
                  ),
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
  final ValueChanged<String> onResolve;

  const _AlertList({
    required this.alerts,
    required this.selectedId,
    required this.onSelect,
    required this.onAssign,
    required this.onAcknowledge,
    required this.onResolve,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: alert.status == 'Resolved'
                                ? const Color(0xFFDCFCE7)
                                : (alert.status == 'Assigned'
                                    ? const Color(0xFFFEF3C7)
                                    : AppColors.bgTertiary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('STATUS: ${alert.status.toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: alert.status == 'Resolved'
                                      ? const Color(0xFF166534)
                                      : (alert.status == 'Assigned'
                                          ? const Color(0xFF92400E)
                                          : AppColors.textSecondary))),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: () => onAssign(alert.id),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 28),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('Assign'),
                        ),
                        if (alert.status != 'Acknowledged' && alert.status != 'Resolved')
                          OutlinedButton(
                            onPressed: () => onAcknowledge(alert.id),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Ack'),
                          ),
                        if (alert.status != 'Resolved')
                          FilledButton(
                            onPressed: () => onResolve(alert.id),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                              backgroundColor: const Color(0xFF16A34A),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Resolve'),
                          ),
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
  final ValueChanged<SurveillanceAlert> onInvestigate;

  const _AlertDetail({
    required this.alert,
    required this.onInvestigate,
  });

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
            'anomaly in ${a.title.toLowerCase()} presentations across sentinel '
            'sites in ${a.region} over the past reporting window.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
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
                const MutedText('contributing active surveillance reports'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Recommended Action'),
          const SizedBox(height: 8),
          const Text(
            '• Review clinical trends across top reporting facilities.\n'
            '• Dispatch rapid diagnostic swabs and transport media.\n'
            '• Escalate to state IDSP nodal unit if trend continues.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onInvestigate(a),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Initiate Investigation Protocol'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
