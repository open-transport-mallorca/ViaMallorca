import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// A provider class for managing the application's locale.
class LocaleProvider with ChangeNotifier {
  Locale? locale;

  /// Constructs a [LocaleProvider] instance with the given [locale].
  LocaleProvider({required this.locale});

  /// Sets the [newLocale] as the current locale if it is supported.
  /// If [newLocale] is not supported or is null, the current locale remains unchanged.
  void setLocale(Locale? newLocale) {
    if (!AppLocalizations.supportedLocales.contains(newLocale) &&
        newLocale != null) return;
    locale = newLocale;
    notifyListeners();
  }
}
