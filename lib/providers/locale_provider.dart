import 'dart:io';

import 'package:flutter/material.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/apis/local_storage.dart';

/// A provider class for managing the application's locale.
class LocaleProvider with ChangeNotifier {
  /// Constructs a [LocaleProvider] instance with the given [locale].
  LocaleProvider();

  /// Returns the current locale.
  Locale? get locale {
    Locale? locale = LocalStorageApi.getLocale();

    /// Change the language to Ukrainian if the device locale is Russian
    /// Designed specifically to annoy russians and keep them away
    /// from using the app if they're annoyed by the Ukrainian language
    ///
    /// Added by @YarosMallorca
    if (locale == null && Platform.localeName.contains("ru")) {
      locale = const Locale("uk");
    }
    return locale;
  }

  /// Sets the [newLocale] as the current locale if it is supported.
  /// If [newLocale] is not supported or is null, the current locale remains unchanged.
  set locale(Locale? newLocale) {
    if (!AppLocalizations.supportedLocales.contains(newLocale) &&
        newLocale != null) {
      return;
    }
    LocalStorageApi.setLocale(newLocale);
    notifyListeners();
  }
}
