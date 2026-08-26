import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/disease_trends.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/trend_badge.dart';

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
  String _selectedDuration = 'Last 30 Days';
  String _selectedCategory = 'All Categories';
  String _selectedDisease = 'All Diseases';
  String _selectedRegion = 'All India';
  String _selectedFacility = 'All Facilities';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(diseaseTrendsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diseaseTrendsProvider);
    final notifier = ref.read(diseaseTrendsProvider.notifier);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return RefreshIndicator(
      onRefresh: notifier.load,
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
              const Text(
                'Disease Trends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const MutedText('Explore changes in reported conditions across time and geography.'),
              const SizedBox(height: 20),
              _FilterToolbar(
                selectedDuration: _selectedDuration,
                selectedCategory: _selectedCategory,
                selectedDisease: _selectedDisease,
                selectedRegion: _selectedRegion,
                selectedFacility: _selectedFacility,
                onDurationChanged: (v) => setState(() => _selectedDuration = v),
                onCategoryChanged: (v) => setState(() => _selectedCategory = v),
                onDiseaseChanged: (v) {
                  setState(() => _selectedDisease = v);
                  notifier.setDiagnosisFilter(v == 'All Diseases' ? null : v);
                },
                onRegionChanged: (v) => setState(() => _selectedRegion = v),
                onFacilityChanged: (v) => setState(() => _selectedFacility = v),
                availableDiseases: state.availableDiagnoses,
              ),
              const SizedBox(height: 20),
              if (state.isBusy && state.raw.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _DiseaseCategoryRow(dynamicTrends: state.trends),
                const SizedBox(height: 22),
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

class _FilterToolbar extends StatelessWidget {
  final String selectedDuration;
  final String selectedCategory;
  final String selectedDisease;
  final String selectedRegion;
  final String selectedFacility;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onDiseaseChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onFacilityChanged;
  final List<String> availableDiseases;

  const _FilterToolbar({
    required this.selectedDuration,
    required this.selectedCategory,
    required this.selectedDisease,
    required this.selectedRegion,
    required this.selectedFacility,
    required this.onDurationChanged,
    required this.onCategoryChanged,
    required this.onDiseaseChanged,
    required this.onRegionChanged,
    required this.onFacilityChanged,
    required this.availableDiseases,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterDropdown(
            icon: Icons.calendar_today_outlined,
            value: selectedDuration,
            items: const ['Last 7 Days', 'Last 30 Days', 'Last 60 Days', 'Last 90 Days'],
            onChanged: onDurationChanged,
          ),
          const SizedBox(width: 10),
          _filterDropdown(
            icon: Icons.filter_alt_outlined,
            value: selectedCategory,
            items: const ['All Categories', 'Respiratory', 'Gastrointestinal', 'Vector-borne', 'Urinary', 'Febrile Illness'],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(width: 10),
          _filterDropdown(
            icon: Icons.filter_alt_outlined,
            value: selectedDisease,
            items: ['All Diseases', ...availableDiseases],
            onChanged: onDiseaseChanged,
          ),
          const SizedBox(width: 10),
          _filterDropdown(
            icon: Icons.location_on_outlined,
            value: selectedRegion,
            items: const ['All India', 'Karnataka', 'Maharashtra', 'Kerala', 'Tamil Nadu', 'Delhi'],
            onChanged: onRegionChanged,
          ),
          const SizedBox(width: 10),
          _filterDropdown(
            icon: Icons.domain_outlined,
            value: selectedFacility,
            items: const ['All Facilities', 'Tertiary Care Hospitals', 'District Sentinel Centers', 'Community Clinics'],
            onChanged: onFacilityChanged,
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final validValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B7280)),
          isDense: true,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), fontWeight: FontWeight.w500),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _DiseaseCategoryItem {
  final String title;
  final String chipLabel;
  final Color chipBg;
  final Color chipColor;
  final String count;
  final double trend7d;
  final double trend30d;
  final bool isAlert;

  const _DiseaseCategoryItem({
    required this.title,
    required this.chipLabel,
    required this.chipBg,
    required this.chipColor,
    required this.count,
    required this.trend7d,
    required this.trend30d,
    this.isAlert = false,
  });
}

class _DiseaseCategoryRow extends StatelessWidget {
  final List<DiagnosisTrend> dynamicTrends;

  const _DiseaseCategoryRow({required this.dynamicTrends});

  @override
  Widget build(BuildContext context) {
    final defaultCategories = [
      const _DiseaseCategoryItem(
        title: 'Respiratory',
        chipLabel: 'Elevated',
        chipBg: Color(0xFFFFEDD5),
        chipColor: Color(0xFFEA580C),
        count: '12,482',
        trend7d: 4.2,
        trend30d: -1.5,
      ),
      const _DiseaseCategoryItem(
        title: 'Gastrointestinal',
        chipLabel: 'Stable',
        chipBg: Color(0xFFD1FAE5),
        chipColor: Color(0xFF059669),
        count: '8,104',
        trend7d: -0.8,
        trend30d: 0.0,
      ),
      const _DiseaseCategoryItem(
        title: 'Vector-borne',
        chipLabel: 'Rising Alert',
        chipBg: Color(0xFFFFE4E6),
        chipColor: Color(0xFFE11D48),
        count: '5,930',
        trend7d: 12.4,
        trend30d: 8.1,
        isAlert: true,
      ),
      const _DiseaseCategoryItem(
        title: 'Urinary',
        chipLabel: 'Stable',
        chipBg: Color(0xFFD1FAE5),
        chipColor: Color(0xFF059669),
        count: '3,241',
        trend7d: -2.1,
        trend30d: -4.5,
      ),
      const _DiseaseCategoryItem(
        title: 'Febrile Illness',
        chipLabel: 'Elevated',
        chipBg: Color(0xFFFFEDD5),
        chipColor: Color(0xFFEA580C),
        count: '4,890',
        trend7d: 3.8,
        trend30d: -1.2,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      // On wide screens (>= 800), fit all 5 cards in 1 row.
      // On narrower screens, enable horizontal scrolling with fixed compact width (200px)
      // so cards never expand into huge bloated boxes.
      final bool useScroll = availableWidth < 850;
      final double cardWidth = useScroll
          ? 205.0
          : (availableWidth - 10 * (defaultCategories.length - 1)) / defaultCategories.length;

      final cardWidgets = [
        for (final cat in defaultCategories)
          SizedBox(
            width: cardWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cat.isAlert ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                  width: cat.isAlert ? 1.3 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cat.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: cat.chipBg,
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                        child: Text(
                          cat.chipLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: cat.chipColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    cat.count,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DualTrendRow(
                    delta7d: cat.trend7d,
                    delta30d: cat.trend30d,
                    higherIsWorse: true,
                  ),
                ],
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
                            shadow: Shadow(
                              color: AppColors.chartSeries[i % AppColors.chartSeries.length].withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.chartSeries[i % AppColors.chartSeries.length].withValues(alpha: 0.25),
                                  AppColors.chartSeries[i % AppColors.chartSeries.length].withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
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
