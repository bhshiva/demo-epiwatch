import 'package:flutter/material.dart';
import '../models/admin_dashboard_models.dart';
import '../theme/app_colors.dart';

/// Interactive India Choropleth Heatmap Widget
class IndiaMapWidget extends StatefulWidget {
  final List<StateIsolateCount> stateCounts;
  final VoidCallback? onViewFullMap;

  const IndiaMapWidget({
    super.key,
    required this.stateCounts,
    this.onViewFullMap,
  });

  @override
  State<IndiaMapWidget> createState() => _IndiaMapWidgetState();
}

class _IndiaMapWidgetState extends State<IndiaMapWidget> {
  String? _selectedState;

  @override
  Widget build(BuildContext context) {
    // Map of state counts for fast lookup
    final countMap = <String, int>{};
    for (final sc in widget.stateCounts) {
      countMap[sc.state.toLowerCase()] = sc.count;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Disease Cases by State (Today)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.onViewFullMap != null)
                TextButton(
                  onPressed: widget.onViewFullMap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View Full Map ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentTeal,
                        ),
                      ),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.accentTeal),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Map Canvas & Heat Legend Row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Vector India Map Visual
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vector Graphic representing India State Heat Distribution
                      CustomPaint(
                        size: Size.infinite,
                        painter: _IndiaMapPainter(
                          stateCounts: countMap,
                          selectedState: _selectedState,
                          onStateHover: (name) {
                            if (_selectedState != name) {
                              setState(() => _selectedState = name);
                            }
                          },
                        ),
                      ),
                      // Tooltip Box when a state is tapped/hovered
                      if (_selectedState != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedState!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Isolates: ${countMap[_selectedState!.toLowerCase()] ?? 0}',
                                  style: const TextStyle(
                                    color: Color(0xFF6EE7B7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Heat Scale Legend
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(color: const Color(0xFF991B1B), label: 'High (> 200)'),
                    const SizedBox(height: 6),
                    _LegendItem(color: const Color(0xFFDC2626), label: '100 – 200'),
                    const SizedBox(height: 6),
                    _LegendItem(color: const Color(0xFFF87171), label: '50 – 100'),
                    const SizedBox(height: 6),
                    _LegendItem(color: const Color(0xFFFCA5A5), label: '20 – 50'),
                    const SizedBox(height: 6),
                    _LegendItem(color: const Color(0xFFFEE2E2), label: '< 20'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Custom Vector Painter for India Map silhouette & states
class _IndiaMapPainter extends CustomPainter {
  final Map<String, int> stateCounts;
  final String? selectedState;
  final ValueChanged<String?> onStateHover;

  _IndiaMapPainter({
    required this.stateCounts,
    required this.selectedState,
    required this.onStateHover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft background grid glow
    final bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)),
      bgPaint,
    );

    // India Outline Vector Representation with State Poly-regions
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw North Region (Jammu, HP, Punjab, Haryana)
    final northPath = Path()
      ..moveTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.45, h * 0.08)
      ..lineTo(w * 0.52, h * 0.18)
      ..lineTo(w * 0.42, h * 0.30)
      ..close();
    _drawRegion(canvas, northPath, 'Punjab', countOf('punjab'), strokePaint);

    // Draw West Region (Rajasthan, Gujarat, Maharashtra)
    final gujaratPath = Path()
      ..moveTo(w * 0.15, h * 0.42)
      ..lineTo(w * 0.32, h * 0.38)
      ..lineTo(w * 0.35, h * 0.55)
      ..lineTo(w * 0.18, h * 0.52)
      ..close();
    _drawRegion(canvas, gujaratPath, 'Gujarat', countOf('gujarat'), strokePaint);

    final mahaPath = Path()
      ..moveTo(w * 0.28, h * 0.54)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.52, h * 0.68)
      ..lineTo(w * 0.30, h * 0.68)
      ..close();
    _drawRegion(canvas, mahaPath, 'Maharashtra', countOf('maharashtra'), strokePaint);

    // Draw Central & North-East (UP, MP, Bihar, WB, Assam, Mizoram)
    final upPath = Path()
      ..moveTo(w * 0.42, h * 0.28)
      ..lineTo(w * 0.65, h * 0.25)
      ..lineTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.45, h * 0.42)
      ..close();
    _drawRegion(canvas, upPath, 'Uttar Pradesh', countOf('uttar pradesh'), strokePaint);

    final mpPath = Path()
      ..moveTo(w * 0.35, h * 0.42)
      ..lineTo(w * 0.58, h * 0.40)
      ..lineTo(w * 0.55, h * 0.54)
      ..lineTo(w * 0.32, h * 0.54)
      ..close();
    _drawRegion(canvas, mpPath, 'Madhya Pradesh', countOf('madhya pradesh'), strokePaint);

    final eastPath = Path()
      ..moveTo(w * 0.62, h * 0.38)
      ..lineTo(w * 0.82, h * 0.32)
      ..lineTo(w * 0.85, h * 0.52)
      ..lineTo(w * 0.65, h * 0.50)
      ..close();
    _drawRegion(canvas, eastPath, 'Mizoram', countOf('mizoram') + countOf('meghalaya'), strokePaint);

    // Draw South Region (Karnataka, AP, Kerala, Tamil Nadu)
    final southPath = Path()
      ..moveTo(w * 0.34, h * 0.68)
      ..lineTo(w * 0.55, h * 0.68)
      ..lineTo(w * 0.48, h * 0.90)
      ..lineTo(w * 0.38, h * 0.88)
      ..close();
    _drawRegion(canvas, southPath, 'Kerala', countOf('kerala') + countOf('karnataka'), strokePaint);
  }

  int countOf(String stateKey) => stateCounts[stateKey] ?? 0;

  void _drawRegion(Canvas canvas, Path path, String name, int count, Paint strokePaint) {
    Color fill;
    if (count >= 200) {
      fill = const Color(0xFF991B1B);
    } else if (count >= 100) {
      fill = const Color(0xFFDC2626);
    } else if (count >= 50) {
      fill = const Color(0xFFF87171);
    } else if (count >= 20) {
      fill = const Color(0xFFFCA5A5);
    } else if (count > 0) {
      fill = const Color(0xFFFEE2E2);
    } else {
      fill = const Color(0xFFE5E7EB);
    }

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _IndiaMapPainter oldDelegate) {
    return oldDelegate.selectedState != selectedState || oldDelegate.stateCounts != stateCounts;
  }
}
