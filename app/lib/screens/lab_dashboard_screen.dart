import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/lab_models.dart';
import '../state/lab_dashboard.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

class LabDashboardScreen extends ConsumerStatefulWidget {
  final String userName;
  final VoidCallback onRecordIsolate;

  const LabDashboardScreen({
    super.key,
    required this.userName,
    required this.onRecordIsolate,
  });

  @override
  ConsumerState<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends ConsumerState<LabDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: load mutates provider state, which must not happen during
    // this widget's own build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.read(labDashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labDashboardProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    return RefreshIndicator(
      onRefresh: () => ref.read(labDashboardProvider.notifier).load(),
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
              _Header(userName: widget.userName, onRecordIsolate: widget.onRecordIsolate),
              const SizedBox(height: 22),
              _KpiRow(summary: state.summary, isBusy: state.isBusy),
              const SizedBox(height: 18),
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PathogenChart(data: state.pathogens)),
                      const SizedBox(width: 18),
                      Expanded(child: _SirChart(data: state.sir)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _PathogenChart(data: state.pathogens),
                    const SizedBox(height: 18),
                    _SirChart(data: state.sir),
                  ],
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
  final String userName;
  final VoidCallback onRecordIsolate;

  const _Header({required this.userName, required this.onRecordIsolate});

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
            const Text('Laboratory Workspace',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'Logged-in: '),
                  TextSpan(
                      text: userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: onRecordIsolate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Record New Isolate'),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final LabSummary summary;
  final bool isBusy;
  const _KpiRow({required this.summary, required this.isBusy});

  @override
  Widget build(BuildContext context) {
    final rate = summary.resistanceRateWeek;
    final rateLabel = rate == null ? '—' : '${(rate * 100).toStringAsFixed(1)}%';
    final tiles = [
      (summary.isolatesToday.toString(), 'Isolates Today', AppColors.accentBlue),
      (summary.pendingCultures.toString(), 'Pending Cultures', AppColors.accentBlue),
      (summary.mdrIsolatesWeek.toString(), 'MDR Isolates (7d)', AppColors.statusCritical),
      (rateLabel, 'Resistance Rate (7d)', AppColors.statusMonitoring),
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

class _PathogenChart extends StatelessWidget {
  final List<PathogenCount> data;
  const _PathogenChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Pathogen Frequency'),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: data.isEmpty
                ? const Center(child: MutedText('No isolates recorded yet.'))
                : BarChart(
                    BarChartData(
                      minY: 0,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.textPrimary,
                        ),
                      ),
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
                            reservedSize: 52,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= data.length) return const SizedBox.shrink();
                              final name = data[i].pathogen;
                              final short = name.length > 14 ? '${name.substring(0, 13)}…' : name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: -0.4,
                                  child: Text(short,
                                      style: const TextStyle(
                                          fontSize: 10.5, color: AppColors.textMuted)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < data.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: data[i].count.toDouble(),
                              color: AppColors.chartBlue,
                              width: 22,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SirChart extends StatelessWidget {
  final List<SirCount> data;
  const _SirChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Susceptibility by Antibiotic (S / I / R)'),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: data.isEmpty
                ? const Center(child: MutedText('No AST results recorded yet.'))
                : BarChart(
                    BarChartData(
                      minY: 0,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.textPrimary,
                        ),
                      ),
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
                            reservedSize: 52,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= data.length) return const SizedBox.shrink();
                              final name = data[i].antibiotic;
                              final short = name.length > 14 ? '${name.substring(0, 13)}…' : name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: -0.4,
                                  child: Text(short,
                                      style: const TextStyle(
                                          fontSize: 10.5, color: AppColors.textMuted)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < data.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: data[i].total.toDouble(),
                              width: 22,
                              borderRadius: BorderRadius.zero,
                              rodStackItems: _stackItems(data[i]),
                            ),
                          ]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            children: const [
              _Legend(color: AppColors.statusNormal, label: 'Susceptible'),
              _Legend(color: AppColors.statusMonitoring, label: 'Intermediate'),
              _Legend(color: AppColors.statusCritical, label: 'Resistant'),
            ],
          ),
        ],
      ),
    );
  }

  List<BarChartRodStackItem> _stackItems(SirCount d) {
    double y = 0;
    final items = <BarChartRodStackItem>[];
    items.add(BarChartRodStackItem(y, y + d.susceptible, AppColors.statusNormal));
    y += d.susceptible;
    items.add(BarChartRodStackItem(y, y + d.intermediate, AppColors.statusMonitoring));
    y += d.intermediate;
    items.add(BarChartRodStackItem(y, y + d.resistant, AppColors.statusCritical));
    y += d.resistant;
    items.add(BarChartRodStackItem(y, y + d.notTested, AppColors.textMuted));
    return items;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]);
}
