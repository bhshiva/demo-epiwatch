import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_strings.dart';
import '../state/locale.dart';
import '../theme/app_colors.dart';

/// The bg/fg pair for a status label, ported from StatusBrushConverter in the
/// WPF client. Case-insensitive because the same word arrives from several
/// backend fields ("Confirmed" diagnosis, "confirmed" isolate status, etc).
class _StatusPalette {
  final Color bg;
  final Color fg;
  const _StatusPalette(this.bg, this.fg);
}

const _statusPalette = <String, _StatusPalette>{
  'confirmed': _StatusPalette(Color(0xFFD1FAE5), Color(0xFF065F46)),
  'resolved': _StatusPalette(Color(0xFFD1FAE5), Color(0xFF065F46)),
  'normal': _StatusPalette(Color(0xFFD1FAE5), Color(0xFF065F46)),
  'final': _StatusPalette(Color(0xFFD1FAE5), Color(0xFF065F46)),
  'susceptible': _StatusPalette(Color(0xFFD1FAE5), Color(0xFF065F46)),
  'suspected': _StatusPalette(Color(0xFFFEF3C7), Color(0xFF92400E)),
  'monitoring': _StatusPalette(Color(0xFFFEF3C7), Color(0xFF92400E)),
  'pending': _StatusPalette(Color(0xFFFEF3C7), Color(0xFF92400E)),
  'intermediate': _StatusPalette(Color(0xFFFEF3C7), Color(0xFF92400E)),
  'probable': _StatusPalette(Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  'preliminary': _StatusPalette(Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  'elevated': _StatusPalette(Color(0xFFFFEDD5), Color(0xFF9A3412)),
  'high': _StatusPalette(Color(0xFFFFEDD5), Color(0xFF9A3412)),
  'critical': _StatusPalette(Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'amr alert': _StatusPalette(Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'resistant': _StatusPalette(Color(0xFFFEE2E2), Color(0xFF991B1B)),
};

const _fallback = _StatusPalette(Color(0xFFEEF2F0), AppColors.textSecondary);

class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette[label.toLowerCase()] ?? _fallback;
    return Consumer(
      builder: (context, ref, _) {
        final lang = ref.watch(localeProvider);
        final keyMap = {
          'suspected': 'status_suspected',
          'probable': 'status_probable',
          'confirmed': 'status_confirmed',
          'normal': 'status_normal',
          'elevated': 'status_elevated',
          'monitoring': 'status_monitoring',
          'critical': 'status_critical',
          'resolved': 'status_resolved',
          'high': 'status_high',
        };
        final translationKey = keyMap[label.toLowerCase()] ?? label;
        final translatedLabel = AppStrings.get(translationKey, lang);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(4)),
          child: Text(
            translatedLabel,
            style: TextStyle(color: palette.fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
