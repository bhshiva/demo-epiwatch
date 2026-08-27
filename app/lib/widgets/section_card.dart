import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_strings.dart';
import '../state/locale.dart';
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
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: margin,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        child: Padding(padding: padding, child: child),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) {
          final lang = ref.watch(localeProvider);
          final keyMap = {
            'Patient Identity': 'patient_identity',
            'Clinical Summary': 'clinical_summary',
            'Diagnosis & Classification': 'diagnosis',
            'ACORN Infection Origin & Syndrome': 'acorn_syndrome',
            'Treatment & Prescriptions': 'treatment_prescriptions',
            'Linked Microbiology / Lab Results': 'lab_link',
            'Specimen & Isolation Details': 'record_culture',
            'Microbiology Lab Record': 'record_culture',
          };
          final translationKey = keyMap[text] ?? text;
          final translatedText = AppStrings.get(translationKey, lang);

          return Text(
            translatedText,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          );
        },
      );
}

class MutedText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  const MutedText(this.text, {super.key, this.textAlign});

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) {
          final lang = ref.watch(localeProvider);
          final keyMap = {
            'Reports are de-identified before aggregation. Coded fields follow WHO GLASS and ICMR-AMRSN vocabularies so data is comparable across facilities.':
                'submit_report_sub',
            'Search an existing patient to continue their record, or register a new one. Names are stored separately from surveillance data and never leave this facility.':
                'patient_sub',
            'Search by name, ABHA number, phone number or facility MRN':
                'search_sub',
          };
          final translationKey = keyMap[text] ?? text;
          final translated = AppStrings.get(translationKey, lang);
          final display =
              translated.isNotEmpty && translated != translationKey
                  ? translated
                  : text;
          return Text(
            display,
            textAlign: textAlign,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          );
        },
      );
}
