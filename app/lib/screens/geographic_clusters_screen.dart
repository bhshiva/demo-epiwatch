import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';

class GeographicClustersScreen extends StatefulWidget {
  const GeographicClustersScreen({super.key});

  @override
  State<GeographicClustersScreen> createState() => _GeographicClustersScreenState();
}

class _GeographicClustersScreenState extends State<GeographicClustersScreen> {
  bool _filterHospital = true;
  bool _filterClinic = true;

  // Facilities around Mumbai metropolitan area for the cluster
  final List<_ClusterFacilityMarker> _allMarkers = const [
    _ClusterFacilityMarker(
      name: 'KEM Hospital Parel',
      type: 'Hospital',
      point: LatLng(18.9986, 72.8436),
      category: _MarkerCategory.highHospitalLoad,
      cases: '42 cases / wk (+52%)',
    ),
    _ClusterFacilityMarker(
      name: 'Sion Municipal Hospital',
      type: 'Hospital',
      point: LatLng(19.0356, 72.8601),
      category: _MarkerCategory.highHospitalLoad,
      cases: '38 cases / wk (+40%)',
    ),
    _ClusterFacilityMarker(
      name: 'Dadar Central Clinic',
      type: 'Clinic',
      point: LatLng(19.0178, 72.8478),
      category: _MarkerCategory.clinicSpike,
      cases: '26 cases / wk (+65%)',
    ),
    _ClusterFacilityMarker(
      name: 'Kurla West Polyclinic',
      type: 'Clinic',
      point: LatLng(19.0657, 72.8792),
      category: _MarkerCategory.clinicSpike,
      cases: '19 cases / wk (+35%)',
    ),
    _ClusterFacilityMarker(
      name: 'Bandra Sentinel Center',
      type: 'Hospital',
      point: LatLng(19.0596, 72.8295),
      category: _MarkerCategory.monitoring,
      cases: '14 cases / wk (Stable)',
    ),
    _ClusterFacilityMarker(
      name: 'Thane Civil Sentinel',
      type: 'Hospital',
      point: LatLng(19.1970, 72.9760),
      category: _MarkerCategory.monitoring,
      cases: '12 cases / wk (Baseline)',
    ),
    _ClusterFacilityMarker(
      name: 'Byculla Municipal Dispensary',
      type: 'Clinic',
      point: LatLng(18.9750, 72.8330),
      category: _MarkerCategory.highHospitalLoad,
      cases: '20 cases / wk (+45%)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1050;

    final visibleMarkers = _allMarkers.where((m) {
      if (m.type == 'Hospital' && !_filterHospital) return false;
      if (m.type == 'Clinic' && !_filterClinic) return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                const Text('Surveillance', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('>', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const Text('Geographic Clusters', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('>', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                Text('Mumbai Respiratory Signal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentTeal)),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            const Text(
              'Respiratory Illness Cluster Mumbai Metropolitan Region',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            // Metadata Badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('HIGH PRIORITY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFE02424))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Detected: 16 Aug 2026, 14:32',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Confidence: 87%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Content Row
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildMapSection(visibleMarkers)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildClusterSummaryCard()),
                  ],
                ),
              )
            else ...[
              _buildMapSection(visibleMarkers),
              const SizedBox(height: 20),
              _buildClusterSummaryCard(),
            ],

            const SizedBox(height: 20),

            // Bottom Recommendation & Action Bar
            _buildBottomActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(List<_ClusterFacilityMarker> visibleMarkers) {
    const clusterCenter = LatLng(19.0178, 72.8478);

    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: clusterCenter,
              initialZoom: 11.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.epiwatch.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: clusterCenter,
                    color: const Color(0xFFE02424).withValues(alpha: 0.12),
                    borderColor: const Color(0xFFE02424).withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                    radius: 65,
                  ),
                  CircleMarker(
                    point: clusterCenter,
                    color: const Color(0xFFF05252).withValues(alpha: 0.18),
                    borderColor: const Color(0xFFF05252).withValues(alpha: 0.6),
                    borderStrokeWidth: 1.5,
                    radius: 35,
                  ),
                ],
              ),
              MarkerLayer(
                markers: visibleMarkers.map((m) {
                  final color = switch (m.category) {
                    _MarkerCategory.highHospitalLoad => const Color(0xFFD32F2F),
                    _MarkerCategory.clinicSpike => const Color(0xFFE65100),
                    _MarkerCategory.monitoring => const Color(0xFF1B5E20),
                  };

                  return Marker(
                    point: m.point,
                    width: 28,
                    height: 28,
                    child: Tooltip(
                      message: '${m.name} (${m.type})\n${m.cases}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Floating "Signal Core" card on top-left
          Positioned(
            top: 14,
            left: 14,
            width: 250,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, size: 15, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      const Text(
                        'Signal Core',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Potential cluster detected across central wards. Not a confirmed outbreak. Requires field verification.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Intensity', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 6,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('78%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _CheckboxItem(
                        label: 'Hospital',
                        value: _filterHospital,
                        onChanged: (v) => setState(() => _filterHospital = v ?? true),
                      ),
                      const SizedBox(width: 10),
                      _CheckboxItem(
                        label: 'Clinic',
                        value: _filterClinic,
                        onChanged: (v) => setState(() => _filterClinic = v ?? true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Legend on bottom-right
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendRow(const Color(0xFFD32F2F), 'High hospital load'),
                  const SizedBox(height: 4),
                  _legendRow(const Color(0xFFE65100), 'Clinic spike'),
                  const SizedBox(height: 4),
                  _legendRow(const Color(0xFF1B5E20), 'Monitoring'),
                  const SizedBox(height: 6),
                  const Text('Leaflet | © OpenStreetMap', style: TextStyle(fontSize: 8.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildClusterSummaryCard() {
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
            'CLUSTER SUMMARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF115E59),
            ),
          ),
          const SizedBox(height: 18),

          // 2x2 Metric Tiles
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _metricBox('8', 'Facilities')),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _metricBox(
                          '↑ +38%',
                          'Reporting Increase',
                          isIncrease: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _metricBox('3', 'Affected Districts')),
                      const SizedBox(width: 14),
                      Expanded(child: _metricBox('6 days', 'Signal Duration')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Expected vs Current footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  children: [
                    TextSpan(text: 'Expected: '),
                    TextSpan(text: '124/wk', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  children: [
                    TextSpan(text: 'Current: '),
                    TextSpan(text: '171/wk', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE02424))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String value, String label, {bool isIncrease = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isIncrease ? const Color(0xFFFFF5F5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIncrease ? const Color(0xFFFED7D7) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isIncrease ? const Color(0xFFE02424) : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF166534)),
                ),
                child: const Center(
                  child: Text('i', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    children: [
                      TextSpan(text: 'Recommended: ', style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: 'Review recent clinical trends across top contributing facilities to rule out artifact.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cluster summary exported to PDF/CSV.')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Export Summary'),
              ),
              OutlinedButton(
                onPressed: () {
                  _showComparisonDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Compare Regions'),
              ),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Viewing Disease Trend time-series for ILI...')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('View Disease Trend'),
              ),
              FilledButton(
                onPressed: () {
                  _showInvestigationDialog(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Create Investigation'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvestigationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initiate Rapid Response Investigation'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign an epidemiological rapid investigation team for the Mumbai Respiratory cluster:'),
            SizedBox(height: 14),
            TextField(
              decoration: InputDecoration(
                labelText: 'Lead Officer',
                hintText: 'e.g. Dr. Meera Iyer (IDSP)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'Sampling Directives',
                hintText: 'Deploy viral transport media to KEM & Sion Hospital',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rapid Investigation team assigned and bulletin dispatched.')),
              );
            },
            child: const Text('Confirm & Dispatch'),
          ),
        ],
      ),
    );
  }

  void _showComparisonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regional Signal Comparison'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mumbai Metropolitan: +38% baseline (Confidence 87%)'),
            SizedBox(height: 6),
            Text('Pune Metropolitan: +22% baseline (Confidence 78%)'),
            SizedBox(height: 6),
            Text('Nashik District: +8% baseline (Confidence 65%)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

enum _MarkerCategory { highHospitalLoad, clinicSpike, monitoring }

class _ClusterFacilityMarker {
  final String name;
  final String type;
  final LatLng point;
  final _MarkerCategory category;
  final String cases;

  const _ClusterFacilityMarker({
    required this.name,
    required this.type,
    required this.point,
    required this.category,
    required this.cases,
  });
}

class _CheckboxItem extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckboxItem({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0F766E),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
