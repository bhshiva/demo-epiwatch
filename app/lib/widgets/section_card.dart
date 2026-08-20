import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The white bordered card used for every dashboard/records section, matching
/// the WPF Card style.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: margin,
        child: Padding(padding: padding, child: child),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      );
}

class MutedText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  const MutedText(this.text, {super.key, this.textAlign});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      );
}
