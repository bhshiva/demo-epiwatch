import 'package:flutter/material.dart';

/// Design tokens carried over verbatim from the WPF client's Colors.xaml.
///
/// The two clients ship side by side until parity, so the values are copied
/// rather than reinterpreted: a doctor moving between desktop and phone should
/// not see two different products.
abstract final class AppColors {
  // Surfaces
  static const bgPrimary = Color(0xFFEDF3EF);
  static const bgSecondary = Color(0xFFFFFFFF);
  static const bgTertiary = Color(0xFFF4F8F5);

  // Text
  static const textPrimary = Color(0xFF1B332A);
  static const textSecondary = Color(0xFF4A665E);
  static const textMuted = Color(0xFF789088);

  // Accents
  static const accentTeal = Color(0xFF0F766E);
  static const accentGreen = Color(0xFF1B5E20);
  static const accentMint = Color(0xFF10B981);
  static const accentBlue = Color(0xFF2563EB);

  // Status. Ordered by escalation; surveillance UI leans on these heavily.
  static const statusNormal = Color(0xFF10B981);
  // Re-stepped from the WPF-inherited 0xFFD97706: that value sits only
  // ΔE 14.4 from statusCritical for a normal-vision viewer (dataviz skill's
  // validator, --mode light), below the 15 floor -- Intermediate and
  // Resistant read as barely distinguishable in the S/I/R chart, which is
  // a real misreading risk in a resistance chart, not a cosmetic one. This
  // value passes at ΔE 19.2. Flagged for the WPF Colors.xaml to pick up
  // too, since CLAUDE.md wants the two clients on one palette.
  static const statusMonitoring = Color(0xFFCA8A04);
  static const statusElevated = Color(0xFFEA580C);
  static const statusCritical = Color(0xFFDC2626);
  // Neutral "no data" indicator (e.g. an antibiotic not yet tested) --
  // deliberately achromatic so it never competes with the status hues
  // above for identity; not a status color itself.
  static const statusNotTested = Color(0xFF94A3B8);

  static const border = Color(0xFFD1DFD6);
  static const primaryButton = Color(0xFF1B4D3E);

  // Colorblind-safe categorical order used for chart series, from
  // ChartTheme.cs in the WPF client.
  static const chartAmber = Color(0xFFEDA100);
  static const chartBlue = Color(0xFF2A78D6);
  static const chartOrange = Color(0xFFEB6834);
  static const chartGreen = Color(0xFF1BAF7A);
  static const chartSeries = [chartAmber, chartBlue, chartOrange, chartGreen];
}
