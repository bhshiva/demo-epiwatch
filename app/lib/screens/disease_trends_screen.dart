import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/disease_trends.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Real day-by-day case counts and real week-over-week/month-over-month
/// deltas, computed from analytics.disease_daily -- not the illustrative
/// ML_PLAN.md-deferred anomaly detection used elsewhere in this workspace
/// (see disease_trends.dart's DiagnosisTrend.trendLabel doc comment: a
/// plain threshold, not a statistical signal).
class DiseaseTrendsScreen extends ConsumerStatefulWidget {
  const DiseaseTrendsScreen({super.key});

  @override
  ConsumerState<DiseaseTrendsScreen> createState() => _DiseaseTrendsScreenState();
}

class _DiseaseTrendsScreenState extends ConsumerState<DiseaseTrendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(diseaseTrendsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diseaseTrendsProvider);
    final notifier = ref.read(diseaseTrendsProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.load,
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
              const Text('Disease Trends',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const MutedText('Explore changes in reported conditions over the last 60 days.'),
              const SizedBox(height: 18),
              _DiagnosisFilter(
                diagnoses: state.availableDiagnoses,
                selected: state.diagnosisFilter,
                onChanged: notifier.setDiagnosisFilter,
              ),
              const SizedBox(height: 18),
              if (state.isBusy && state.raw.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.trends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: MutedText('No cases recorded in this window.')),
                )
              else ...[
                _TrendStatRow(trends: state.trends.take(5).toList()),
                const SizedBox(height: 18),
                _TrendLineChart(seriesByDiagnosis: state.seriesByDiagnosis),
              ],
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

class _DiagnosisFilter extends StatelessWidget {
  final List<String> diagnoses;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _DiagnosisFilter({required this.diagnoses, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String?>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.filter_alt_outlined, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('All Diagnoses', overflow: TextOverflow.ellipsis),
          ),
          for (final d in diagnoses)
            DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _TrendStatRow extends StatelessWidget {
  final List<DiagnosisTrend> trends;
  const _TrendStatRow({required this.trends});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 900 ? trends.length.clamp(1, 5) : (constraints.maxWidth >= 500 ? 2 : 1);
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final trend in trends)
            SizedBox(
              width: (constraints.maxWidth - 14 * (perRow - 1)) / perRow,
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(trend.diagnosis,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        _TrendBadge(label: trend.trendLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${trend.last30d}',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _DeltaLabel(percent: trend.delta7dPercent, suffix: '7d'),
                        const SizedBox(width: 10),
                        _DeltaLabel(percent: trend.delta30dPercent, suffix: '30d'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _TrendBadge extends StatelessWidget {
  final String label;
  const _TrendBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Rising' => AppColors.statusCritical,
      'Falling' => AppColors.statusNormal,
      'New' => AppColors.accentBlue,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DeltaLabel extends StatelessWidget {
  final double? percent;
  final String suffix;
  const _DeltaLabel({required this.percent, required this.suffix});

  @override
  Widget build(BuildContext context) {
    if (percent == null) {
      return Text('— $suffix', style: const TextStyle(fontSize: 11, color: AppColors.textMuted));
    }
    final up = percent! >= 0;
    final color = up ? AppColors.statusCritical : AppColors.statusNormal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: color),
        Text('${percent!.abs().toStringAsFixed(1)}% $suffix',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  final Map<String, Map<String, int>> seriesByDiagnosis;
  const _TrendLineChart({required this.seriesByDiagnosis});

  @override
  Widget build(BuildContext context) {
    // Cap at 4 lines (AppColors.chartSeries' fixed categorical order) --
    // more than that stops being readable as a line chart and belongs in
    // the stat-card list above instead.
    final topDiagnoses = seriesByDiagnosis.entries.toList()
      ..sort((a, b) =>
          b.value.values.fold(0, (s, v) => s + v).compareTo(a.value.values.fold(0, (s, v) => s + v)));
    final shown = topDiagnoses.take(4).toList();

    final allDates = <String>{};
    for (final entry in shown) {
      allDates.addAll(entry.value.keys);
    }
    final dates = allDates.toList()..sort();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Reported Disease Activity'),
          const SizedBox(height: 4),
          MutedText(shown.length < topDiagnoses.length
              ? 'Top ${shown.length} of ${topDiagnoses.length} diagnoses by volume'
              : 'All diagnoses in range'),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: dates.isEmpty
                ? const Center(child: MutedText('No data in this window.'))
                : LineChart(
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
                            reservedSize: 30,
                            interval: (dates.length / 8).clamp(1, dates.length).toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                              final short = dates[i].length >= 10 ? dates[i].substring(5) : dates[i];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(short,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        getTouchLineEnd: (_, _) => double.infinity,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.textPrimary,
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final date = dates[touchedSpots.first.x.toInt()];
                            return [
                              for (var i = 0; i < touchedSpots.length; i++)
                                LineTooltipItem(
                                  i == 0 ? '$date\n' : '',
                                  const TextStyle(
                                      color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${shown[touchedSpots[i].barIndex].key}: ${touchedSpots[i].y.toStringAsFixed(0)}',
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
                        for (var i = 0; i < shown.length; i++)
                          LineChartBarData(
                            spots: [
                              for (var j = 0; j < dates.length; j++)
                                FlSpot(j.toDouble(), (shown[i].value[dates[j]] ?? 0).toDouble()),
                            ],
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: AppColors.chartSeries[i % AppColors.chartSeries.length],
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shown.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 10,
                      height: 10,
                      color: AppColors.chartSeries[i % AppColors.chartSeries.length]),
                  const SizedBox(width: 6),
                  Text(shown[i].key, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}
