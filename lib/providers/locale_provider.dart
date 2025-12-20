import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    Locale? locale = LocalStorageApi.getLocale();

    /// Change the language to Ukrainian if the device locale is Russian
    /// Designed specifically to annoy russians and keep them away
    /// from using the app if they're annoyed by the Ukrainian language
    ///
    /// Added by @YarosMallorca
    if (locale == null && Platform.localeName.contains('ru')) {
      locale = const Locale('uk');
    }

    return locale;
  }

  void setLocale(Locale? newLocale) {
    if (newLocale != null &&
        !AppLocalizations.supportedLocales.contains(newLocale)) {
      return;
    }

    LocalStorageApi.setLocale(newLocale);
    state = newLocale;
  }
}
