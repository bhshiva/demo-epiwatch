import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_models.dart';
import '../services/demo_data.dart';
import '../state/dashboard.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String doctorName;
  final String facilityName;
  final VoidCallback onSubmitReport;
  final VoidCallback onViewRecords;

  const DashboardScreen({
    super.key,
    required this.doctorName,
    required this.facilityName,
    required this.onSubmitReport,
    required this.onViewRecords,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: load mutates provider state, which must not happen during
    // this widget's own build.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(dashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardProvider.notifier).load(),
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
              _Header(
                doctorName: widget.doctorName,
                facilityName: widget.facilityName,
                onSubmitReport: widget.onSubmitReport,
              ),
              const SizedBox(height: 22),
              const SectionCard(
                child: _PatientQueue(),
              ),
              const SizedBox(height: 18),
              _KpiRow(summary: state.summary, alertCount: DemoData.outbreakAlerts.length),
              const SizedBox(height: 18),
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Expanded(child: _TrendCard()),
                      SizedBox(width: 18),
                      SizedBox(width: 380, child: _RightRail()),
                    ],
                  ),
                )
              else
                const Column(
                  children: [
                    _TrendCard(),
                    SizedBox(height: 18),
                    _RightRail(),
                  ],
                ),
              const SizedBox(height: 18),
              SectionCard(
                child: _RecentReports(
                  reports: state.recentReports,
                  isBusy: state.isBusy,
                  onViewAll: widget.onViewRecords,
                ),
              ),
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

class _Header extends StatelessWidget {
  final String doctorName;
  final String facilityName;
  final VoidCallback onSubmitReport;

  const _Header({
    required this.doctorName,
    required this.facilityName,
    required this.onSubmitReport,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clinical Workspace',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'Logged-in Doctor: '),
                  TextSpan(
                      text: doctorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const TextSpan(text: '  •  Facility: '),
                  TextSpan(
                      text: facilityName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.accentTeal)),
                ],
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: onSubmitReport,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Submit Clinical Report'),
        ),
      ],
    );
  }
}

class _PatientQueue extends StatelessWidget {
  const _PatientQueue();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Today's Patient Queue"),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            headingTextStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            columns: const [
              DataColumn(label: Text('PATIENT')),
              DataColumn(label: Text('AGE / GENDER')),
              DataColumn(label: Text('CONDITION')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('LAST VISIT')),
            ],
            rows: [
              for (final p in DemoData.patientQueue)
                DataRow(cells: [
                  DataCell(Text(p.name)),
                  DataCell(Text(p.ageGender)),
                  DataCell(Text(p.condition)),
                  DataCell(StatusChip(label: p.status)),
                  DataCell(MutedText(p.lastVisit)),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final DashboardSummary summary;
  final int alertCount;
  const _KpiRow({required this.summary, required this.alertCount});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (summary.patientsToday.toString(), 'Patients Today', AppColors.accentBlue),
      (summary.reportsSubmittedTotal.toString(), 'Reports Submitted', AppColors.accentBlue),
      (summary.activeConditions.toString(), 'Active Conditions', AppColors.accentBlue),
      (alertCount.toString(), 'Facility Alerts', AppColors.accentMint),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 700 ? 4 : 2;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final t in tiles)
            SizedBox(
              width: (constraints.maxWidth - 18 * (perRow - 1)) / perRow,
              child: SectionCard(
                child: Column(
                  children: [
                    Text(t.$1,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: t.$3)),
                    const SizedBox(height: 4),
                    MutedText(t.$2),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) {
    final labels = DemoData.trendLabels();
    final colors = [AppColors.chartAmber, AppColors.chartBlue, AppColors.chartOrange];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Disease Activity This Week (Aggregate Trends)'),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style:
                                  const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                  ),
                ),
                lineBarsData: [
                  for (var i = 0; i < DemoData.weeklyTrends.length; i++)
                    LineChartBarData(
                      spots: [
                        for (var j = 0; j < DemoData.weeklyTrends[i].values.length; j++)
                          FlSpot(j.toDouble(), DemoData.weeklyTrends[i].values[j]),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: colors[i % colors.length],
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3.5,
                          color: Colors.white,
                          strokeColor: colors[i % colors.length],
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            children: [
              for (var i = 0; i < DemoData.weeklyTrends.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, color: colors[i % colors.length]),
                  const SizedBox(width: 6),
                  Text(DemoData.weeklyTrends[i].name,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Facility Signals'),
              const SizedBox(height: 12),
              for (final s in DemoData.facilitySignals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.category,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            MutedText(s.change),
                          ],
                        ),
                      ),
                      StatusChip(label: s.level),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('⚠  ', style: TextStyle(fontSize: 14)),
                Flexible(child: SectionTitle('Active Outbreak Alerts')),
              ]),
              const SizedBox(height: 12),
              for (final a in DemoData.outbreakAlerts)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.only(left: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: (_statusFg(a.severity)), width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(a.title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(label: a.severity),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(a.detail,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusFg(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'amr alert':
        return const Color(0xFF991B1B);
      case 'high':
        return const Color(0xFF9A3412);
      case 'resolved':
        return const Color(0xFF065F46);
      default:
        return AppColors.textMuted;
    }
  }
}

class _RecentReports extends StatelessWidget {
  final List<ReportSummary> reports;
  final bool isBusy;
  final VoidCallback onViewAll;

  const _RecentReports({required this.reports, required this.isBusy, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Recent Reports')),
            TextButton(onPressed: onViewAll, child: const Text('View All History')),
          ],
        ),
        const SizedBox(height: 8),
        if (isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: MutedText('No reports submitted yet. Tap "Submit Clinical Report" to begin.'),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              headingTextStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              columns: const [
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('CONDITION')),
                DataColumn(label: Text('COMPLAINTS')),
                DataColumn(label: Text('DIAGNOSIS STATUS')),
              ],
              rows: [
                for (final r in reports)
                  DataRow(cells: [
                    DataCell(Text(r.reportDate)),
                    DataCell(Text(r.diagnosis ?? '—')),
                    DataCell(Text(r.complaints ?? '—')),
                    DataCell(StatusChip(label: r.diagnosisStatus ?? 'Unknown')),
                  ]),
              ],
            ),
          ),
      ],
    );
  }
}
