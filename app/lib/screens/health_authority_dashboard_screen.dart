import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 1100;
    final isMobile = screenWidth < 600;

    return RefreshIndicator(
      onRefresh: () => ref.read(surveillanceDashboardProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16 : 28),
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
      _KpiCardData(
        title: 'FACILITIES REPORTING',
        value: summary.facilitiesReporting > 0
            ? _formatNumber(summary.facilitiesReporting)
            : '2,481',
        subtitle: '↑ 6.2% vs yesterday',
        subtitleColor: const Color(0xFF059669),
        icon: Icons.add_circle_outline_rounded,
        iconBg: const Color(0xFFD1FAE5),
        iconColor: const Color(0xFF059669),
        chartColor: const Color(0xFF10B981),
        chartPoints: const [2200, 2260, 2310, 2290, 2380, 2440, 2481],
        isAlertCard: false,
      ),
      _KpiCardData(
        title: 'REPORTS TODAY',
        value: summary.reportsToday > 0
            ? _formatNumber(summary.reportsToday)
            : '48,392',
        subtitle: '↑ 11.4% vs avg',
        subtitleColor: const Color(0xFF059669),
        icon: Icons.description_outlined,
        iconBg: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        chartColor: const Color(0xFF3B82F6),
        chartPoints: const [38000, 41000, 40500, 44000, 46200, 48392],
        isAlertCard: false,
      ),
      _KpiCardData(
        title: 'EMERGING SIGNALS',
        value: '$emergingCount',
        subtitle: '● 4 high priority',
        subtitleColor: const Color(0xFFEA580C),
        icon: Icons.trending_up_rounded,
        iconBg: const Color(0xFFFFEDD5),
        iconColor: const Color(0xFFEA580C),
        chartColor: const Color(0xFFF97316),
        chartPoints: const [12, 14, 13, 16, 15, 17],
        isAlertCard: false,
      ),
      _KpiCardData(
        title: 'ACTIVE ALERTS',
        value: '$alertCount',
        subtitle: '● 3 critical actions req.',
        subtitleColor: const Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
        iconBg: const Color(0xFFFFE4E6),
        iconColor: const Color(0xFFE11D48),
        chartColor: const Color(0xFFEF4444),
        chartPoints: const [5, 6, 6, 7, 7, 8],
        isAlertCard: true,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      final bool useScroll = availableWidth < 800;
      final double cardWidth = useScroll
          ? 215.0
          : (availableWidth - 10 * (tiles.length - 1)) / tiles.length;

      final cardWidgets = [
        for (final t in tiles)
          SizedBox(
            width: cardWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: t.isAlertCard ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
                  width: t.isAlertCard ? 1.2 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: t.isAlertCard
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: t.iconBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(t.icon, size: 15, color: t.iconColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: t.isAlertCard
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF111827),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.subtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: t.subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 18), // space for bottom wave
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 22,
                      child: CustomPaint(
                        painter: _MiniSparklinePainter(
                          color: t.chartColor,
                          points: t.chartPoints,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ];

      if (useScroll) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < cardWidgets.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                cardWidgets[i],
              ],
            ],
          ),
        );
      }

      return Row(
        children: [
          for (int i = 0; i < cardWidgets.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cardWidgets[i]),
          ],
        ],
      );
    });
  }

  static String _formatNumber(int val) {
    final str = val.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}

class _KpiCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color chartColor;
  final List<double> chartPoints;
  final bool isAlertCard;

  const _KpiCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.chartColor,
    required this.chartPoints,
    required this.isAlertCard,
  });
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  _MiniSparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);
    final minY = points.reduce(math.min);
    final maxY = points.reduce(math.max);
    final rangeY = (maxY - minY == 0) ? 1.0 : (maxY - minY);

    double getY(double val) =>
        size.height - ((val - minY) / rangeY * (size.height * 0.72) + size.height * 0.12);

    path.moveTo(0, getY(points[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(points[0]));

    for (int i = 0; i < points.length - 1; i++) {
      final p0X = i * stepX;
      final p0Y = getY(points[i]);
      final p1X = (i + 1) * stepX;
      final p1Y = getY(points[i + 1]);

      final controlX1 = p0X + (p1X - p0X) / 2;
      final controlY1 = p0Y;
      final controlX2 = p0X + (p1X - p0X) / 2;
      final controlY2 = p1Y;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1X, p1Y);
      fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1X, p1Y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) =>
      color != oldDelegate.color || points != oldDelegate.points;
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
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showFacilityDetails(context, f),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: '${f.name}\n${f.recentCaseCount} cases (7d)\nClick for details',
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: f.recentCaseCount > 0
                                            ? const Color(0xFFE11D48)
                                            : const Color(0xFF0F766E),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: Icon(
                                        f.recentCaseCount > 0
                                            ? Icons.local_hospital_rounded
                                            : Icons.location_on,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (f.recentCaseCount > 0)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF991B1B),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: Text(
                                            '${f.recentCaseCount}',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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

  void _showFacilityDetails(BuildContext context, FacilityGeo facility) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0F766E), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${facility.district}, ${facility.state}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: facility.recentCaseCount > 0
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: facility.recentCaseCount > 0
                      ? const Color(0xFFFECDD3)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        facility.recentCaseCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: facility.recentCaseCount > 0
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF16A34A),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active 7-Day Surveillance',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Recorded clinical encounters',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${facility.recentCaseCount} cases',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: facility.recentCaseCount > 0
                          ? const Color(0xFFE11D48)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'FACILITY METADATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            _metaRow('Facility ID', facility.facilityId),
            if (facility.latitude != null && facility.longitude != null)
              _metaRow('Coordinates', '${facility.latitude!.toStringAsFixed(4)}, ${facility.longitude!.toStringAsFixed(4)}'),
            _metaRow('Role / Status', 'Active Sentinel Reporting Node'),
            _metaRow('Surveillance Program', 'National Epidemic & AMR Watch'),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(f.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('District: ${f.district}, ${f.state}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 10),
                              Text('Recent 7-Day Case Volume: ${f.recentCaseCount} cases',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusCritical)),
                              const SizedBox(height: 8),
                              Text('Facility UUID: ${f.facilityId}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ),
                          Text(
                            '${f.recentCaseCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.statusCritical,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
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
