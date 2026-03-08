import 'package:flutter/material.dart';

import 'app_strings_en.dart';
import 'app_strings_ja.dart';
import 'app_strings_zh_hans.dart';
import 'app_strings_zh_hant.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  String t(String key, [Map<String, Object?> params = const {}]) {
    final localeKey = _localeToKey(locale);
    final localized = _localizedValues[localeKey] ??
        _localizedValues[locale.languageCode] ??
        _localizedValues['en']!;
    final fallback = _localizedValues['en']!;

    var value = localized[key] ?? fallback[key] ?? key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  static bool isLocaleSupported(Locale locale) {
    final localeKey = _localeToKey(locale);
    if (_localizedValues.containsKey(localeKey)) {
      return true;
    }
    return _localizedValues.containsKey(locale.languageCode);
  }

  static String _localeToKey(Locale locale) {
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    if (locale.languageCode == 'zh') {
      if (scriptCode == 'hant') {
        return 'zh-Hant';
      }

      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        return 'zh-Hant';
      }
    }

    return locale.languageCode;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': appStringsEn,
    'zh': appStringsZhHans,
    'zh-Hant': appStringsZhHant,
    'ja': appStringsJa,
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.isLocaleSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContextExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
