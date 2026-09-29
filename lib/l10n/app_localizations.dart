import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'languages/en.dart';
import 'languages/th.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('th'), Locale('en')];
  static const translations = <String, Map<String, String>>{'th': th, 'en': en};

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String t(String key) => (translations[locale.languageCode] ?? th)[key] ?? key;
  String category(String key) => t('category_$key');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.translations.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
