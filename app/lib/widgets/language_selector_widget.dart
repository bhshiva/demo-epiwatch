import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/locale.dart';
import '../theme/app_colors.dart';

class LanguageSelectorWidget extends ConsumerWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: currentLang,
          isExpanded: true,
          icon: const Icon(Icons.language, size: 18, color: AppColors.textSecondary),
          isDense: true,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          onChanged: (AppLanguage? newLang) {
            if (newLang != null) {
              ref.read(localeProvider.notifier).setLanguage(newLang);
            }
          },
          items: AppLanguage.values.map((AppLanguage lang) {
            return DropdownMenuItem<AppLanguage>(
              value: lang,
              child: Text(
                '${lang.nativeName} (${lang.englishName})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
