import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_models.dart';
import '../services/app_strings.dart';
import '../services/demo_data.dart';
import '../state/dashboard.dart';
import '../state/locale.dart';
import '../theme/app_colors.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(dashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top Header Bar ────────────────────────────────────────────────────
        _TopBar(
          doctorName: widget.doctorName,
          facilityName: widget.facilityName,
          onSubmitReport: widget.onSubmitReport,
        ),
        // ── Scrollable Content ─────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(dashboardProvider.notifier).load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.error != null) ...[
                      _ErrorBanner(message: state.error!),
                      const SizedBox(height: 16),
                    ],
                    // ── KPI Cards ───────────────────────────────────────────
                    _KpiRow(
                        summary: state.summary,
                        alertCount: DemoData.outbreakAlerts.length),
                    const SizedBox(height: 20),
                    // ── Chart + Right Rail (Right Rail ABOVE Patient Queue) ──
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: _TrendCard()),
                          const SizedBox(width: 20),
                          SizedBox(width: 340, child: _RightRail()),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const _TrendCard(),
                          const SizedBox(height: 20),
                          _RightRail(),
                        ],
                      ),
                    const SizedBox(height: 20),
                    // ── Patient Queue (reduced width ~65%) ──────────────────
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 65,
                            child: _ModernCard(
                              child: _PatientQueue(
                                  reports: state.recentReports),
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(flex: 35, child: SizedBox()),
                        ],
                      )
                    else
                      _ModernCard(
                        child: _PatientQueue(reports: state.recentReports),
                      ),
                    const SizedBox(height: 20),
                    // ── Recent Reports (full width) ─────────────────────────
                    _ModernCard(
                      child: _RecentReports(
                        reports: state.recentReports,
                        isBusy: state.isBusy,
                        onViewAll: widget.onViewRecords,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String doctorName;
  final String facilityName;
  final VoidCallback onSubmitReport;

  const _TopBar({
    required this.doctorName,
    required this.facilityName,
    required this.onSubmitReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Page title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer(
                builder: (context, ref, _) => Text(
                  AppStrings.get('dashboard', ref.watch(localeProvider)),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              Text('$facilityName • Dr. $doctorName',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          // Search bar
          SizedBox(
            width: 260,
            height: 36,
            child: Consumer(
              builder: (context, ref, _) => TextField(
                decoration: InputDecoration(
                  hintText: AppStrings.get('search_placeholder', ref.watch(localeProvider)),
                  hintStyle:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bgTertiary,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.accentTeal, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification bell
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          // Submit report button
          Consumer(
            builder: (context, ref, _) => FilledButton.icon(
              onPressed: onSubmitReport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                AppStrings.get('submit_report_nav', ref.watch(localeProvider)),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Card wrapper (replaces SectionCard styling)
// ─────────────────────────────────────────────────────────────────────────────

class _ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ModernCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────────────────────

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
                  style: const TextStyle(
                      color: AppColors.statusCritical, fontSize: 13))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Row — reference-style cards with icon, big number, trend badge, subtitle
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final DashboardSummary summary;
  final int alertCount;
  const _KpiRow({required this.summary, required this.alertCount});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiData(
        label: 'Patients Today',
        value: summary.patientsToday.toString(),
        trend: '+5%',
        trendUp: true,
        subtitle: 'Active cases tracked',
        icon: Icons.people_outline,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEFF6FF),
      ),
      _KpiData(
        label: 'Reports Submitted',
        value: summary.reportsSubmittedTotal.toString(),
        trend: '+12%',
        trendUp: true,
        subtitle: 'Total clinical reports',
        icon: Icons.assignment_outlined,
        iconColor: const Color(0xFF0F766E),
        iconBg: const Color(0xFFECFDF5),
      ),
      _KpiData(
        label: 'Active Conditions',
        value: summary.activeConditions.toString(),
        trend: '-3%',
        trendUp: false,
        subtitle: 'Distinct diagnoses active',
        icon: Icons.biotech_outlined,
        iconColor: const Color(0xFFEA580C),
        iconBg: const Color(0xFFFFF7ED),
      ),
      _KpiData(
        label: 'Facility Alerts',
        value: alertCount.toString(),
        trend: '+2',
        trendUp: false,
        subtitle: 'Active outbreak signals',
        icon: Icons.warning_amber_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEF2F2),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 700 ? 4 : 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final t in tiles)
            SizedBox(
              width: (constraints.maxWidth - 16 * (perRow - 1)) / perRow,
              child: _KpiCard(data: t),
            ),
        ],
      );
    });
  }
}

class _KpiData {
  final String label;
  final String value;
  final String trend;
  final bool trendUp;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _KpiData({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendUp,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 20),
              ),
              const Spacer(),
              // Trend badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: data.trendUp
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.trendUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: data.trendUp
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      data.trend,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: data.trendUp
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Consumer(
            builder: (context, ref, _) {
              final lang = ref.watch(localeProvider);
              final keyMap = {
                'Patients Today': 'kpi_patients_today',
                'Reports Submitted': 'kpi_reports_submitted',
                'Active Conditions': 'kpi_active_conditions',
                'Facility Alerts': 'kpi_facility_alerts',
              };
              final key = keyMap[data.label] ?? data.label;
              return Text(
                AppStrings.get(key, lang),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              );
            },
          ),
          const SizedBox(height: 2),
          Consumer(
            builder: (context, ref, _) {
              final lang = ref.watch(localeProvider);
              final keyMap = {
                'Active cases tracked': 'kpi_sub_patients_today',
                'Total clinical reports': 'kpi_sub_reports_submitted',
                'Distinct diagnoses active': 'kpi_sub_active_conditions',
                'Active outbreak signals': 'kpi_sub_facility_alerts',
              };
              final key = keyMap[data.subtitle] ?? data.subtitle;
              return Text(
                AppStrings.get(key, lang),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Queue Table
// ─────────────────────────────────────────────────────────────────────────────

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
      final status = (r.diagnosisStatus != null &&
              r.diagnosisStatus!.trim().isNotEmpty)
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
    final pageItems =
        queue.isEmpty ? <QueuePatient>[] : queue.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, _) => Text(
                  AppStrings.get('todays_patient_queue', ref.watch(localeProvider)),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
            if (queue.length > _pageSize) ...[
              Consumer(
                builder: (context, ref, _) {
                  final lang = ref.watch(localeProvider);
                  final showingStr = AppStrings.get('showing', lang);
                  final ofStr = AppStrings.get('of', lang);
                  return Text(
                    '$showingStr ${startIndex + 1}–$endIndex $ofStr ${queue.length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  );
                },
              ),
              const SizedBox(width: 4),
              _PageButton(
                icon: Icons.chevron_left,
                enabled: safePage > 0,
                onTap: () => setState(() => _currentPage = safePage - 1),
              ),
              const SizedBox(width: 4),
              _PageButton(
                icon: Icons.chevron_right,
                enabled: safePage < totalPages - 1,
                onTap: () => setState(() => _currentPage = safePage + 1),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Consumer(
            builder: (context, ref, _) {
              final lang = ref.watch(localeProvider);
              final colPatient = AppStrings.get('col_patient', lang);
              final colAgeGender = AppStrings.get('col_age_gender', lang);
              final colCondition = AppStrings.get('col_condition', lang);
              final colStatus = AppStrings.get('col_status', lang);
              final colLastVisit = AppStrings.get('col_last_visit', lang);

              return SizedBox(
                width: constraints.maxWidth,
                child: _StyledDataTable(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5), // PATIENT
                    1: FlexColumnWidth(1.2), // AGE / GENDER
                    2: FlexColumnWidth(2.5), // CONDITION
                    3: FlexColumnWidth(1.2), // STATUS
                    4: FlexColumnWidth(1.4), // LAST VISIT
                  },
                  columns: [colPatient, colAgeGender, colCondition, colStatus, colLastVisit],
                  rows: [
                    for (final p in pageItems)
                      [
                        _PatientCell(name: p.name),
                        Text(p.ageGender,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        Text(p.condition,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary)),
                        StatusChip(label: p.status),
                        Text(p.lastVisit,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend Chart
// ─────────────────────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) {
    final labels = DemoData.trendLabels();
    final colors = [AppColors.chartAmber, AppColors.chartBlue, AppColors.chartOrange];

    return _ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Disease Activity This Week (Aggregate Trends)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('This Week',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 16,
            children: [
              for (var i = 0; i < DemoData.weeklyTrends.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(DemoData.weeklyTrends[i].name,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
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
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  getTouchLineEnd: (_, _) => double.infinity,
                  getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                      .map((_) => TouchedSpotIndicatorData(
                            const FlLine(
                                color: AppColors.border, strokeWidth: 1.5),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeColor:
                                    bar.color ?? AppColors.textPrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ))
                      .toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
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
                                  color:
                                      touchedSpots[i].bar.color ?? Colors.white,
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
                        for (var j = 0;
                            j < DemoData.weeklyTrends[i].values.length;
                            j++)
                          FlSpot(j.toDouble(),
                              DemoData.weeklyTrends[i].values[j]),
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
                            colors[i % colors.length].withValues(alpha: 0.18),
                            colors[i % colors.length].withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right Rail — Facility Signals + Outbreak Alerts
// ─────────────────────────────────────────────────────────────────────────────

class _RightRail extends StatelessWidget {
  const _RightRail();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModernCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer(
                builder: (context, ref, _) => Text(
                  AppStrings.get('facility_signals', ref.watch(localeProvider)),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),
              for (final s in DemoData.facilitySignals) ...[
                _SignalRow(signal: s),
                if (s != DemoData.facilitySignals.last)
                  const Divider(height: 16, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ModernCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.warning_amber_outlined,
                        size: 16, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) => Text(
                        AppStrings.get('active_outbreak_alerts', ref.watch(localeProvider)),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${DemoData.outbreakAlerts.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final a in DemoData.outbreakAlerts)
                _AlertItem(alert: a),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignalRow extends ConsumerWidget {
  final dynamic signal;
  const _SignalRow({required this.signal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final categoryKeyMap = {
      'Respiratory Symptoms': 'sig_respiratory_symptoms',
      'Gastrointestinal': 'sig_gastrointestinal',
      'Febrile Illness': 'sig_febrile_illness',
    };
    final changeKeyMap = {
      '+23% this week': 'sig_change_resp',
      '-8% this week': 'sig_change_gastro',
      '+11% this week': 'sig_change_febrile',
    };

    final categoryKey = categoryKeyMap[signal.category] ?? signal.category;
    final changeKey = changeKeyMap[signal.change] ?? signal.change;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get(categoryKey, lang),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.get(changeKey, lang),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        StatusChip(label: signal.level),
      ],
    );
  }
}

class _AlertItem extends ConsumerWidget {
  final dynamic alert;
  const _AlertItem({required this.alert});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'amr alert':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'resolved':
        return const Color(0xFF16A34A);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final titleKeyMap = {
      'Influenza-like Illness Outbreak Warning': 'alert_ili_title',
      'AMR Signal - E. coli Reduced Susceptibility': 'alert_amr_title',
      'Dengue Fever Cluster (Resolved)': 'alert_dengue_title',
    };
    final detailKeyMap = {
      'Public health authorities have triggered an alert for elevated respiratory activity in the Mumbai Metropolitan Region. Request cultures / Rapid Antigen Tests for qualifying cases.': 'alert_ili_detail',
      'Karnataka Apex Lab reports rising Ciprofloxacin resistance in E. coli urinary isolates. Consider culture-guided prescribing for suspected UTIs.': 'alert_amr_detail',
      'Delhi Central Wards cluster has been resolved after vector control intervention. Continue routine reporting for febrile illness.': 'alert_dengue_detail',
    };

    final titleKey = titleKeyMap[alert.title] ?? alert.title;
    final detailKey = detailKeyMap[alert.detail] ?? alert.detail;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: _severityColor(alert.severity), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.get(titleKey, lang),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: alert.severity),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            AppStrings.get(detailKey, lang),
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Reports Table
// ─────────────────────────────────────────────────────────────────────────────

class _RecentReports extends ConsumerStatefulWidget {
  final List<ReportSummary> reports;
  final bool isBusy;
  final VoidCallback onViewAll;

  const _RecentReports({
    required this.reports,
    required this.isBusy,
    required this.onViewAll,
  });

  @override
  ConsumerState<_RecentReports> createState() => _RecentReportsState();
}

class _RecentReportsState extends ConsumerState<_RecentReports> {
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
    final pageItems =
        reports.isEmpty ? <ReportSummary>[] : reports.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppStrings.get('recent_reports', ref.watch(localeProvider)),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            if (reports.length > _pageSize) ...[
              Text(
                '${AppStrings.get('showing', ref.watch(localeProvider))} ${startIndex + 1}–$endIndex ${AppStrings.get('of', ref.watch(localeProvider))} ${reports.length}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              _PageButton(
                icon: Icons.chevron_left,
                enabled: safePage > 0,
                onTap: () => setState(() => _currentPage = safePage - 1),
              ),
              const SizedBox(width: 4),
              _PageButton(
                icon: Icons.chevron_right,
                enabled: safePage < totalPages - 1,
                onTap: () => setState(() => _currentPage = safePage + 1),
              ),
              const SizedBox(width: 12),
            ],
            OutlinedButton(
              onPressed: widget.onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryButton,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(AppStrings.get('view_all_history', ref.watch(localeProvider)),
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 36, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                      AppStrings.get('no_reports_submitted', ref.watch(localeProvider)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              child: _StyledDataTable(
                columnWidths: const {
                  0: FlexColumnWidth(1.2), // DATE
                  1: FlexColumnWidth(2.2), // PATIENT
                  2: FlexColumnWidth(2.2), // CONDITION
                  3: FlexColumnWidth(2.5), // COMPLAINTS
                  4: FlexColumnWidth(1.3), // STATUS
                },
                columns: [
                  AppStrings.get('col_date', ref.watch(localeProvider)),
                  AppStrings.get('col_patient', ref.watch(localeProvider)),
                  AppStrings.get('col_condition', ref.watch(localeProvider)),
                  AppStrings.get('col_complaints', ref.watch(localeProvider)),
                  AppStrings.get('col_diagnosis_status', ref.watch(localeProvider))
                ],
                rows: [
                  for (final r in pageItems)
                    [
                      Text(r.reportDate,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                      _PatientCell(
                          name: (r.patientName != null && r.patientName!.trim().isNotEmpty)
                              ? r.patientName!.trim()
                              : 'Registered Patient'),
                      Text(r.diagnosis ?? '—',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textPrimary)),
                      Text(r.complaints ?? '—',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                      StatusChip(label: r.diagnosisStatus ?? 'Unknown'),
                    ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Custom data table with reference-style styling (alternating rows, no dividers)
class _StyledDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final Map<int, TableColumnWidth>? columnWidths;

  const _StyledDataTable({
    required this.columns,
    required this.rows,
    this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultColumnWidth: columnWidths != null
          ? const FlexColumnWidth(1)
          : const IntrinsicColumnWidth(),
      columnWidths: columnWidths,
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          children: [
            for (final col in columns)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 24, 8),
                child: Text(col,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.3)),
              ),
          ],
        ),
        // Data rows
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isOdd
                  ? AppColors.bgTertiary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            children: [
              for (final cell in rows[i])
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 7, 24, 7),
                  child: cell,
                ),
            ],
          ),
      ],
    );
  }
}

/// Patient name cell with avatar initial
class _PatientCell extends StatelessWidget {
  final String name;
  const _PatientCell({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.primaryButton.withValues(alpha: 0.1),
          child: Text(initial,
              style: const TextStyle(
                  color: AppColors.primaryButton,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5)),
        ),
        const SizedBox(width: 8),
        Text(name,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

/// Small icon page navigation button
class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? AppColors.textSecondary : AppColors.textMuted),
      ),
    );
  }
}
