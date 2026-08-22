import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_dashboard_models.dart';
import '../state/admin_dashboard_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/india_map_widget.dart';
import '../widgets/status_chip.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentTeal),
        ),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load dashboard: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(adminDashboardProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _AdminDashboardContent(data: data),
      ),
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  final AdminDashboardData data;

  const _AdminDashboardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar
          _buildHeader(context),
          const SizedBox(height: 24),

          // Top KPI Cards Row
          _buildKpiCardsRow(data.kpi),
          const SizedBox(height: 24),

          // Middle Grid: Disease Trend, India Map, Top 5 AMR Pathogens
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildDiseaseTrendCard(data.diseaseTrends)),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 380,
                        child: IndiaMapWidget(stateCounts: data.stateCounts),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildTopPathogensCard(data.topPathogens)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildDiseaseTrendCard(data.diseaseTrends),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 380,
                      child: IndiaMapWidget(stateCounts: data.stateCounts),
                    ),
                    const SizedBox(height: 20),
                    _buildTopPathogensCard(data.topPathogens),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Lower Grid: AMR Resistance Combos & E. coli Ciprofloxacin Trend
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildAmrCombosCard(data.topResistanceCombos)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildEcoliTrendCard(data.ecoliTrend)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAmrCombosCard(data.topResistanceCombos),
                    const SizedBox(height: 20),
                    _buildEcoliTrendCard(data.ecoliTrend),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Bottom Grid: Recent Alerts & Quick Stats
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildRecentAlertsCard(data.recentAlerts)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildQuickStatsCard(data.quickStats)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRecentAlertsCard(data.recentAlerts),
                    const SizedBox(height: 20),
                    _buildQuickStatsCard(data.quickStats),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Integrated Disease & AMR Surveillance Overview',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date Filter Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aug 15 – Aug 21, 2025 ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
                ],
              ),
            ),
            // Filters Button
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list_rounded, size: 16),
              label: const Text('Filters'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            // User Avatar & Role Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accentTeal.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: AppColors.accentTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Admin',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'National Surveillance Unit',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCardsRow(AdminKpiData kpi) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Total Disease Cases',
            value: '24,532',
            changeText: '▲ 12.4% vs last 7 days',
            isPositive: true,
            icon: Icons.personal_injury_outlined,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            title: 'Total Facilities Reporting',
            value: '1,248',
            changeText: '▲ 8.7% vs last 7 days',
            isPositive: true,
            icon: Icons.local_hospital_outlined,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            title: 'AMR Resistance Rate (All)',
            value: '28.7%',
            changeText: '▲ 6.3% vs last 7 days',
            isPositive: false,
            icon: Icons.science_outlined,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFFA855F7),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            title: 'Active Alerts',
            value: '12',
            changeText: '▲ 3 new vs last 7 days',
            isPositive: false,
            icon: Icons.warning_amber_rounded,
            iconBg: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseTrendCard(List<DiseaseTrendPoint> points) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Disease Trend (Top 5)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Text('Last 7 Days ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend Row
          Row(
            children: const [
              _LegendDot(color: Color(0xFF2563EB), label: 'Dengue'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF059669), label: 'Malaria'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFFD97706), label: 'Typhoid'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF7C3AED), label: 'Pneumonia'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFFDC2626), label: 'Viral Fever'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DiseaseTrendPainter(points: points),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPathogensCard(List<PathogenStat> pathogens) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'AMR Resistance Rate (Top 5 Pathogens)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend Header
          Row(
            children: const [
              _LegendDot(color: Color(0xFFDC2626), label: 'Resistance Rate (%)'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF94A3B8), label: 'No. of Isolates Tested'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: pathogens.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final p = pathogens[idx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.pathogen, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${p.resistanceRate}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (p.resistanceRate / 50.0).clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmrCombosCard(List<ResistanceCombo> combos) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AMR Surveillance (Top Resistance Combinations)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 0,
              headingRowHeight: 36,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Pathogen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Antibiotic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Resistance Rate (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Trend (vs last 7 days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('No. of Isolates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Districts Affected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Risk Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
              rows: combos.map((c) {
                return DataRow(cells: [
                  DataCell(Text(c.pathogen, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text(c.antibiotic, style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${c.resistanceRate}%',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626)))),
                  DataCell(Text('▲ ${c.trend}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                  DataCell(Text('${c.isolates}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${c.districts}', style: const TextStyle(fontSize: 13))),
                  DataCell(StatusChip(label: c.riskLevel)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoliTrendCard(List<EcoliTrendPoint> points) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AMR Trend – E. coli (Ciprofloxacin)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _LegendDot(color: Color(0xFF2563EB), label: 'Resistance Rate (%)'),
              _LegendDot(color: Color(0xFF64748B), label: '-- EWMA'),
              _LegendDot(color: Color(0xFFDC2626), label: '-- CUSUM'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 180,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _EcoliTrendPainter(points: points),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Side Stat Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current (Aug 21)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    const Text('39.3%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                    const SizedBox(height: 8),
                    const Text('EWMA: 32.7%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Text('CUSUM: 24.8', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    const StatusChip(label: 'High'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlertsCard(List<AdminAlert> alerts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Alerts & Signals',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 0,
              headingRowHeight: 36,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Alert ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Pathogen / Disease', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Detected At', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
              rows: alerts.map((a) {
                return DataRow(cells: [
                  DataCell(Text(a.alertId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                  DataCell(Text(a.type, style: const TextStyle(fontSize: 12.5))),
                  DataCell(Text(a.pathogen, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                  DataCell(Text(a.location, style: const TextStyle(fontSize: 12.5))),
                  DataCell(StatusChip(label: a.severity)),
                  DataCell(Text(a.detectedAt, style: const TextStyle(fontSize: 12))),
                  DataCell(StatusChip(label: a.status)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(AdminQuickStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats (Today)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 18),
          _QuickStatRow(
            icon: Icons.assignment_outlined,
            label: 'Reports Received',
            value: '${stats.reportsReceived}',
          ),
          const SizedBox(height: 14),
          _QuickStatRow(
            icon: Icons.science_outlined,
            label: 'Lab Tests Completed',
            value: '${stats.labTestsCompleted}',
          ),
          const SizedBox(height: 14),
          _QuickStatRow(
            icon: Icons.domain_outlined,
            label: 'New Facilities Reporting',
            value: '${stats.newFacilities}',
          ),
          const SizedBox(height: 14),
          _QuickStatRow(
            icon: Icons.map_outlined,
            label: 'Districts Reporting',
            value: stats.districtsReporting,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;
  final bool isPositive;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.changeText,
    required this.isPositive,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            changeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuickStatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accentTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _DiseaseTrendPainter extends CustomPainter {
  final List<DiseaseTrendPoint> points;
  _DiseaseTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final maxVal = 4000.0;

    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
    ];

    for (int lineIdx = 0; lineIdx < 5; lineIdx++) {
      final path = Path();
      final paint = Paint()
        ..color = colors[lineIdx]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < points.length; i++) {
        final x = (i / (points.length - 1)) * w;
        final p = points[i];
        double val = 0;
        if (lineIdx == 0) val = p.dengue.toDouble();
        if (lineIdx == 1) val = p.malaria.toDouble();
        if (lineIdx == 2) val = p.typhoid.toDouble();
        if (lineIdx == 3) val = p.pneumonia.toDouble();
        if (lineIdx == 4) val = p.viralFever.toDouble();

        final y = h - ((val / maxVal) * h);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EcoliTrendPainter extends CustomPainter {
  final List<EcoliTrendPoint> points;
  _EcoliTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final maxVal = 50.0;

    final ratePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final ratePath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * w;
      final y = h - ((points[i].resistanceRate / maxVal) * h);
      if (i == 0) {
        ratePath.moveTo(x, y);
      } else {
        ratePath.lineTo(x, y);
      }
    }
    canvas.drawPath(ratePath, ratePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
