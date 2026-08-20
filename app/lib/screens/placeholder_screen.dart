import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Stands in for a screen not yet ported from the WPF client.
///
/// The nav lists every destination from the start so the shell can be exercised
/// end to end; this makes an unported screen obvious rather than looking like a
/// screen that loaded nothing.
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Not yet ported from the desktop client.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
