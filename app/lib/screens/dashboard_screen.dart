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
              SectionCard(
                child: _PatientQueue(reports: state.recentReports),
              ),
              const SizedBox(height: 18),
              _KpiRow(summary: state.summary, alertCount: DemoData.outbreakAlerts.length),
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: _TrendCard()),
                    SizedBox(width: 18),
                    SizedBox(width: 380, child: _RightRail()),
                  ],
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

class _PatientQueue extends StatefulWidget {
  final List<ReportSummary> reports;
  const _PatientQueue({required this.reports});

  @override
  State<_PatientQueue> createState() => _PatientQueueState();
}

class _PatientQueueState extends State<_PatientQueue> {
  int _currentPage = 0;
  static const int _pageSize = 7;

  String _formatLastVisit(String? createdAtIso, String reportDate) {
    DateTime? dt;
    if (createdAtIso != null && createdAtIso.isNotEmpty) {
      dt = DateTime.tryParse(createdAtIso);
    }
    dt ??= DateTime.tryParse(reportDate);
    if (dt == null) return 'Just now';

    final now = DateTime.now();
    final target = dt.isUtc ? dt.toLocal() : dt;
    final diff = now.difference(target);

    if (diff.inSeconds < 45 || diff.isNegative) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return mins <= 1 ? '1 min ago' : '$mins mins ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return hours <= 1 ? '1 hour ago' : '$hours hours ago';
    } else if (diff.inDays < 2) {
      return 'Yesterday';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} days ago';
    } else {
      return reportDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<QueuePatient> queue = [];

    // Dynamically populate live reports registered or updated
    for (final r in widget.reports) {
      final name = (r.patientName != null && r.patientName!.trim().isNotEmpty)
          ? r.patientName!.trim()
          : 'Registered Patient';
      final ageGender = (r.ageGender != null && r.ageGender!.trim().isNotEmpty)
          ? r.ageGender!.trim()
          : '—';
      final condition = (r.diagnosis != null && r.diagnosis!.trim().isNotEmpty)
          ? r.diagnosis!.trim()
          : (r.complaints != null && r.complaints!.trim().isNotEmpty
              ? r.complaints!.trim()
              : '—');
      final status = (r.diagnosisStatus != null && r.diagnosisStatus!.trim().isNotEmpty)
          ? r.diagnosisStatus!.trim()
          : 'Suspected';
      final lastVisit = _formatLastVisit(r.createdAt, r.reportDate);

      queue.add(QueuePatient(
        name: name,
        ageGender: ageGender,
        condition: condition,
        status: status,
        lastVisit: lastVisit,
      ));
    }

    // Merge with demo data so table UI stays rich and full
    for (final p in DemoData.patientQueue) {
      if (!queue.any((q) => q.name.toLowerCase() == p.name.toLowerCase())) {
        queue.add(p);
      }
    }

    final totalPages = (queue.length / _pageSize).ceil();
    final safePage = _currentPage >= totalPages ? 0 : _currentPage;
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize > queue.length)
        ? queue.length
        : startIndex + _pageSize;
    final pageItems = queue.isEmpty ? <QueuePatient>[] : queue.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle("Today's Patient Queue")),
            if (queue.length > _pageSize) ...[
              Text(
                'Showing ${startIndex + 1}–$endIndex of ${queue.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                tooltip: 'Previous batch',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
                tooltip: 'Next batch',
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 36,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 64,
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
              for (final p in pageItems)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: t.$3)),
                    const SizedBox(height: 6),
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
                  getTouchLineEnd: (_, _) => double.infinity,
                  getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                      .map((_) => TouchedSpotIndicatorData(
                            FlLine(color: AppColors.border, strokeWidth: 1.5),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeColor: bar.color ?? AppColors.textPrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ))
                      .toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    // Without this, fl_chart falls back to a bare stack of
                    // numbers with no series name -- exactly the "what is
                    // this value even for" confusion this was reported for.
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final date = labels[touchedSpots.first.x.toInt()];
                      return [
                        for (var i = 0; i < touchedSpots.length; i++)
                          LineTooltipItem(
                            i == 0 ? '$date\n' : '',
                            const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(
                                text:
                                    '${DemoData.weeklyTrends[touchedSpots[i].barIndex].name}: ${touchedSpots[i].y.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: touchedSpots[i].bar.color ?? Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ];
                    },
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
                      shadow: Shadow(
                        color: colors[i % colors.length].withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            colors[i % colors.length].withValues(alpha: 0.25),
                            colors[i % colors.length].withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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

class _RecentReports extends StatefulWidget {
  final List<ReportSummary> reports;
  final bool isBusy;
  final VoidCallback onViewAll;

  const _RecentReports({
    required this.reports,
    required this.isBusy,
    required this.onViewAll,
  });

  @override
  State<_RecentReports> createState() => _RecentReportsState();
}

class _RecentReportsState extends State<_RecentReports> {
  int _currentPage = 0;
  static const int _pageSize = 7;

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports;
    final totalPages = (reports.length / _pageSize).ceil();
    final safePage = _currentPage >= totalPages ? 0 : _currentPage;
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize > reports.length)
        ? reports.length
        : startIndex + _pageSize;
    final pageItems = reports.isEmpty ? <ReportSummary>[] : reports.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Recent Reports')),
            if (reports.length > _pageSize) ...[
              Text(
                'Showing ${startIndex + 1}–$endIndex of ${reports.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                tooltip: 'Previous batch',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
                tooltip: 'Next batch',
              ),
              const SizedBox(width: 12),
            ],
            TextButton(onPressed: widget.onViewAll, child: const Text('View All History')),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.isBusy)
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
              columnSpacing: 36,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 64,
              headingTextStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              columns: const [
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('CONDITION')),
                DataColumn(label: Text('COMPLAINTS')),
                DataColumn(label: Text('DIAGNOSIS STATUS')),
              ],
              rows: [
                for (final r in pageItems)
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
