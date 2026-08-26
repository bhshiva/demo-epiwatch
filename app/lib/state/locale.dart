import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिंदी'),
  marathi('mr', 'Marathi', 'मराठी'),
  tamil('ta', 'Tamil', 'தமிழ்'),
  telugu('te', 'Telugu', 'తెలుగు'),
  bengali('bn', 'Bengali', 'বাংলা');

  final String code;
  final String englishName;
  final String nativeName;

  const AppLanguage(this.code, this.englishName, this.nativeName);
}

class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.english;

  void setLanguage(AppLanguage lang) {
    state = lang;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);
