import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AMRWatchScreen extends StatefulWidget {
  const AMRWatchScreen({super.key});

  @override
  State<AMRWatchScreen> createState() => _AMRWatchScreenState();
}

class _AMRWatchScreenState extends State<AMRWatchScreen> {
  final List<_PathogenResistanceRow> _pathogenRows = const [
    _PathogenResistanceRow(
      pathogen: 'Acinetobacter baumannii',
      antibiotic: 'Meropenem',
      region: 'Karnataka',
      isolatesTested: 6,
      resistanceRate: 88,
      isSevere: true,
    ),
    _PathogenResistanceRow(
      pathogen: 'Salmonella Typhi',
      antibiotic: 'Ciprofloxacin',
      region: 'Karnataka',
      isolatesTested: 5,
      resistanceRate: 80,
      isSevere: true,
    ),
    _PathogenResistanceRow(
      pathogen: 'E. coli',
      antibiotic: 'Ciprofloxacin',
      region: 'Karnataka',
      isolatesTested: 13,
      resistanceRate: 69,
      isSevere: true,
    ),
    _PathogenResistanceRow(
      pathogen: 'Klebsiella pneumoniae',
      antibiotic: 'Ceftriaxone',
      region: 'Karnataka',
      isolatesTested: 4,
      resistanceRate: 54,
      isSevere: false,
    ),
    _PathogenResistanceRow(
      pathogen: 'Pseudomonas aeruginosa',
      antibiotic: 'Ceftazidime',
      region: 'Karnataka',
      isolatesTested: 3,
      resistanceRate: 49,
      isSevere: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle
            const Text(
              'AMR Watch',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Monitoring antimicrobial resistance trends and prescribing densities across participating facilities',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),

            // Top 4 KPI Cards
            _buildKpiRow(),
            const SizedBox(height: 22),

            // Two main content cards
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildPathogenTableCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildPrescriptionDensityChartCard()),
                  ],
                ),
              )
            else ...[
              _buildPathogenTableCard(),
              const SizedBox(height: 20),
              _buildPrescriptionDensityChartCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 800;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _kpiCard(
            width: isCompact ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
            number: '3',
            numberColor: const Color(0xFFE02424),
            label: 'Active AMR Signals',
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFE02424),
          ),
          _kpiCard(
            width: isCompact ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
            number: '42',
            numberColor: AppColors.textPrimary,
            label: 'Total Isolates Logged',
            icon: Icons.show_chart,
            iconColor: const Color(0xFF0694A2),
          ),
          _kpiCard(
            width: isCompact ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
            number: '24',
            numberColor: AppColors.textPrimary,
            label: 'Resistant Isolates',
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFFFF5722),
          ),
          _kpiCard(
            width: isCompact ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
            number: '61%',
            numberColor: AppColors.textPrimary,
            label: 'Antibiotic Prescription Density',
            icon: Icons.trending_up,
            iconColor: const Color(0xFF7E3AF2),
          ),
        ],
      );
    });
  }

  Widget _kpiCard({
    required double width,
    required String number,
    required Color numberColor,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathogenTableCard() {
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
            'Pathogen Resistance Surveillance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              headingTextStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              horizontalMargin: 12,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('PATHOGEN')),
                DataColumn(label: Text('ANTIBIOTIC\nCLASS / NAME')),
                DataColumn(label: Text('REGION')),
                DataColumn(label: Text('ISOLATES\nTESTED')),
                DataColumn(label: Text('RESISTANCE\nRATE')),
              ],
              rows: _pathogenRows.map((r) {
                final barColor = r.isSevere ? const Color(0xFFE02424) : const Color(0xFFE65100);

                return DataRow(
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Drilldown for ${r.pathogen}')),
                          );
                        },
                        child: Text(
                          r.pathogen,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(r.antibiotic, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    DataCell(
                      Text(r.region, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    DataCell(
                      Text('${r.isolatesTested}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${r.resistanceRate}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: barColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: r.resistanceRate / 100,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFE5E7EB),
                                color: barColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDensityChartCard() {
    const dates = ['2026-08-13', '2026-08-15', '2026-08-17', '2026-08-20', '2026-08-23', '2026-08-26'];

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
            'Antibiotic Prescriptions (Drug Class Density)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 12,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFF3F4F6),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 3,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < dates.length) {
                          return Text(
                            dates[idx],
                            style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: AppColors.border),
                    left: BorderSide(color: AppColors.border),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final idx = touchedSpots.first.x.toInt();
                      final dateStr = idx >= 0 && idx < dates.length ? dates[idx] : '';
                      return [
                        LineTooltipItem(
                          '$dateStr\nCephalosporins: 2\nFluoroquinolones: 5\nOther: 1\nPenicillins: 3',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ];
                    },
                  ),
                ),
                lineBarsData: [
                  // Cephalosporins (Purple)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF8B5CF6),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 4),
                      FlSpot(2, 4),
                      FlSpot(3, 2),
                      FlSpot(4, 4),
                      FlSpot(5, 2),
                    ],
                  ),
                  // Fluoroquinolones (Teal)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF0F766E),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    spots: const [
                      FlSpot(0, 6),
                      FlSpot(1, 8),
                      FlSpot(2, 8),
                      FlSpot(3, 5),
                      FlSpot(4, 7),
                      FlSpot(5, 10),
                    ],
                  ),
                  // Other (Gray)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF64748B),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    spots: const [
                      FlSpot(0, 6),
                      FlSpot(1, 5),
                      FlSpot(2, 2),
                      FlSpot(3, 1),
                      FlSpot(4, 1),
                      FlSpot(5, 1),
                    ],
                  ),
                  // Penicillins (Blue)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF2563EB),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    spots: const [
                      FlSpot(0, 6),
                      FlSpot(1, 5),
                      FlSpot(2, 3),
                      FlSpot(3, 3),
                      FlSpot(4, 5),
                      FlSpot(5, 5),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Chart Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(const Color(0xFF8B5CF6), 'Cephalosporins'),
              _legendDot(const Color(0xFF0F766E), 'Fluoroquinolones'),
              _legendDot(const Color(0xFF64748B), 'Other'),
              _legendDot(const Color(0xFF2563EB), 'Penicillins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PathogenResistanceRow {
  final String pathogen;
  final String antibiotic;
  final String region;
  final int isolatesTested;
  final int resistanceRate;
  final bool isSevere;

  const _PathogenResistanceRow({
    required this.pathogen,
    required this.antibiotic,
    required this.region,
    required this.isolatesTested,
    required this.resistanceRate,
    required this.isSevere,
  });
}
