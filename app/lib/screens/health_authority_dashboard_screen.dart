import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/surveillance_models.dart';
import '../state/surveillance_dashboard.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Read-only, all-facility view: case trends, resistance rates, an outbreak
/// map, and a simple case-count watch list. No risk scoring/alerting here --
/// that's the deliberately-deferred ML layer (see ML_PLAN.md, kept local,
/// not committed). This is descriptive, not predictive.
class HealthAuthorityDashboardScreen extends ConsumerStatefulWidget {
  final String userName;
  const HealthAuthorityDashboardScreen({super.key, required this.userName});

  @override
  ConsumerState<HealthAuthorityDashboardScreen> createState() =>
      _HealthAuthorityDashboardScreenState();
}

class _HealthAuthorityDashboardScreenState
    extends ConsumerState<HealthAuthorityDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.read(surveillanceDashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surveillanceDashboardProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    return RefreshIndicator(
      onRefresh: () => ref.read(surveillanceDashboardProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 18),
              ],
              const Text('Live Surveillance',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              MutedText('Logged-in: ${widget.userName}'),
              const SizedBox(height: 22),
              _KpiRow(
                summary: state.summary,
                emergingCount: state.alerts.where((a) => a.alertLevel.toLowerCase() == 'watch').length,
                alertCount: state.alerts.where((a) => a.alertLevel.toLowerCase() == 'elevated' || a.alertLevel.toLowerCase() == 'critical').length,
              ),
              const SizedBox(height: 18),
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _OutbreakMap(facilities: state.facilities)),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: _EmergingSignalsPanel(alerts: state.alerts, facilities: state.facilities)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _OutbreakMap(facilities: state.facilities),
                    const SizedBox(height: 18),
                    _EmergingSignalsPanel(alerts: state.alerts, facilities: state.facilities),
                  ],
                ),
              const SizedBox(height: 18),
              _WatchList(facilities: state.watchList),
              const SizedBox(height: 18),
              _DiseaseDailyChart(data: state.diseaseDaily),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.statusCritical.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.statusCritical.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.statusCritical, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.statusCritical, fontSize: 13))),
        ]),
      );
}

class _KpiRow extends StatelessWidget {
  final SurveillanceSummary summary;
  final int emergingCount;
  final int alertCount;
  const _KpiRow({required this.summary, required this.emergingCount, required this.alertCount});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('${summary.facilitiesReporting}', 'Facilities Reporting (30d)', Icons.add_business_outlined,
          AppColors.statusNormal),
      ('${summary.reportsToday}', 'Reports Today', Icons.description_outlined, AppColors.accentBlue),
      ('$emergingCount', 'Emerging Signals',
          Icons.show_chart, AppColors.statusMonitoring),
      ('$alertCount', 'Active Alerts', Icons.warning_amber_outlined,
          AppColors.statusCritical),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final t in tiles)
            SizedBox(
              width: (constraints.maxWidth - 16 * (perRow - 1)) / perRow,
              child: SectionCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MutedText(t.$2),
                          const SizedBox(height: 6),
                          Text(t.$1,
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w700, color: t.$4)),
                        ],
                      ),
                    ),
                    Icon(t.$3, color: t.$4.withValues(alpha: 0.6), size: 22),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Illustrative -- see HealthAuthorityDemoData's doc comment. Not built
/// from any detection engine.
class _EmergingSignalsPanel extends StatelessWidget {
  final List<Alert> alerts;
  final List<FacilityGeo> facilities;
  const _EmergingSignalsPanel({required this.alerts, required this.facilities});

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('Emerging Signals')),
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
                          letterSpacing: 0.5,
                          color: AppColors.statusMonitoring)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const MutedText('Real-time alerts generated by Isolation Forest & SPC.'),
            const SizedBox(height: 14),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: MutedText('No active signals detected.'),
              )
            else
              for (final alert in alerts.take(3))
                Builder(
                  builder: (context) {
                    final fac = facilities.firstWhere(
                      (f) => f.facilityId == alert.facilityId,
                      orElse: () => FacilityGeo(
                        facilityId: alert.facilityId,
                        name: 'Unknown Facility',
                        district: 'Unknown',
                        state: 'Unknown',
                        recentCaseCount: 0,
                      ),
                    );
                    final severity = alert.alertLevel.toUpperCase();
                    final deviationLabel = '+${(alert.compositeRiskScore * 100).toInt()}% risk';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _severityColor(severity).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SeverityChip(severity: severity),
                              const Spacer(),
                              if (alert.date != null)
                                Text('Detected: ${alert.date}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${alert.organism ?? 'Unknown Pathogen'} Anomaly',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          MutedText('${fac.name} (${fac.district}, ${fac.state})'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const MutedText('Score '),
                                Text(alert.compositeRiskScore.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary)),
                              ]),
                              Text(deviationLabel,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.statusCritical)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                ),
          ],
        ),
      );
}

Color _severityColor(String severity) => switch (severity) {
      'CRITICAL' => AppColors.statusCritical,
      'HIGH' => AppColors.statusElevated,
      'MEDIUM' => AppColors.statusMonitoring,
      _ => AppColors.textMuted,
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

class _OutbreakMap extends StatelessWidget {
  final List<FacilityGeo> facilities;
  const _OutbreakMap({required this.facilities});

  @override
  Widget build(BuildContext context) {
    final located = facilities.where((f) => f.latitude != null && f.longitude != null).toList();
    // India's approximate centroid, so the map has somewhere sensible to
    // point before any facility data has loaded.
    const fallbackCenter = LatLng(22.9734, 78.6569);

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: SectionTitle('Facility Case Counts (7d)'),
          ),
          SizedBox(
            height: 360,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: located.isNotEmpty
                      ? LatLng(located.first.latitude!, located.first.longitude!)
                      : fallbackCenter,
                  initialZoom: located.isNotEmpty ? 5.5 : 4.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.epiwatch.app',
                  ),
                  // Heat glow: three concentric, decreasingly-opaque
                  // circles per facility with active cases, radius scaled
                  // by case count (sqrt, so one outlier facility doesn't
                  // swallow the map). flutter_map has no first-class
                  // heatmap layer, so this is the standard stacked-
                  // translucent-circle technique instead of pulling in a
                  // separate plugin for one effect.
                  CircleLayer(
                    circles: [
                      for (final f in located.where((f) => f.recentCaseCount > 0)) ...[
                        CircleMarker(
                          point: LatLng(f.latitude!, f.longitude!),
                          radius: _heatRadius(f.recentCaseCount) * 1.8,
                          color: AppColors.statusCritical.withValues(alpha: 0.06),
                        ),
                        CircleMarker(
                          point: LatLng(f.latitude!, f.longitude!),
                          radius: _heatRadius(f.recentCaseCount) * 1.1,
                          color: AppColors.statusCritical.withValues(alpha: 0.14),
                        ),
                        CircleMarker(
                          point: LatLng(f.latitude!, f.longitude!),
                          radius: _heatRadius(f.recentCaseCount) * 0.55,
                          color: AppColors.statusCritical.withValues(alpha: 0.28),
                        ),
                      ],
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final f in located)
                        Marker(
                          point: LatLng(f.latitude!, f.longitude!),
                          width: 36,
                          height: 36,
                          child: Tooltip(
                            message: '${f.name}\n${f.recentCaseCount} cases (7d)',
                            child: Icon(
                              Icons.location_on,
                              size: 32,
                              color: f.recentCaseCount > 0
                                  ? AppColors.statusCritical
                                  : AppColors.accentBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _heatRadius(int caseCount) => 18 + math.sqrt(caseCount) * 14;
}

class _WatchList extends StatelessWidget {
  final List<FacilityGeo> facilities;
  const _WatchList({required this.facilities});

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Highest Case Counts (7d)'),
            const SizedBox(height: 4),
            const MutedText('A sort, not an alert -- risk scoring is not built yet.'),
            const SizedBox(height: 14),
            if (facilities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: MutedText('No recent cases recorded.'),
              )
            else
              for (final f in facilities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(f.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ),
                      Text('${f.recentCaseCount}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.statusCritical)),
                    ],
                  ),
                ),
          ],
        ),
      );
}

class _DiseaseDailyChart extends StatelessWidget {
  final List<DiseaseDailyPoint> data;
  const _DiseaseDailyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    // Group by diagnosis so multiple conditions don't collapse into one
    // ambiguous total.
    final byDiagnosis = <String, int>{};
    for (final point in data) {
      byDiagnosis[point.diagnosis] = (byDiagnosis[point.diagnosis] ?? 0) + point.caseCount;
    }
    final entries = byDiagnosis.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Statewide Cases by Diagnosis (30d)'),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: MutedText('No cases recorded in this window.')),
            )
          else
            _DiagnosisBarList(entries: entries.take(10).toList()),
        ],
      ),
    );
  }
}

/// Horizontal magnitude comparison across diagnoses. Single series (one
/// hue, no legend needed -- the section title already says what's
/// plotted), so the only job here is getting proportional widths and a
/// direct value label right.
class _DiagnosisBarList extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _DiagnosisBarList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxValue = entries.first.value;
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Tooltip(
              message: '${entry.key}: ${entry.value}',
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // FractionallySizedBox scales to whatever bounded
                      // width its parent (Expanded) actually resolves to --
                      // unlike a manually computed pixel width from a
                      // LayoutBuilder, it can't end up unbounded/infinite
                      // and silently render every bar full-width regardless
                      // of value, which is what happened before this fix.
                      child: FractionallySizedBox(
                        widthFactor: maxValue == 0 ? 0 : entry.value / maxValue,
                        child: Container(
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.chartBlue,
                            // Rounded data-end only (the bar's leading edge
                            // stays square, matching the vertical-bar spec
                            // rotated 90 degrees).
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text('${entry.value}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
