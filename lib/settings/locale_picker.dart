import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/extensions/capitalize_string.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:locale_names/locale_names.dart';

/// A widget that allows the user to pick a locale.
class LocalePicker extends StatefulWidget {
  const LocalePicker({super.key});

  @override
  State<LocalePicker> createState() => _LocalePickerState();
}

class _LocalePickerState extends State<LocalePicker> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    getLocale();
  }

  /// Sets the theme mode and updates the locale.
  ///
  /// It also notifies the [LocaleProvider] of the change.
  /// The UI will be updated to reflect the new locale.
  void setThemeMode(Locale? locale) {
    setState(() {
      _locale = locale;
    });
    LocalStorageApi.setLocale(locale);
    Provider.of<LocaleProvider>(context, listen: false).setLocale(locale);
  }

  /// Retrieves the saved locale from local storage.
  Future<void> getLocale() async {
    final locale = LocalStorageApi.getLocale();
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppLocalizations.of(context)!.language,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    AppLocalizations.supportedLocales.length + 1, (index) {
                  if (index == 0) {
                    return ListTile(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio(
                              value: null,
                              groupValue: _locale,
                              onChanged: (value) => setThemeMode(null)),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.system),
                        ],
                      ),
                      onTap: () => setThemeMode(null),
                    );
                  }
                  final locale = AppLocalizations.supportedLocales[index - 1];
                  return ListTile(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio(
                              value: locale,
                              groupValue: _locale,
                              onChanged: (value) => setThemeMode(value)),
                          const SizedBox(width: 8),
                          Text(Locale.fromSubtags(
                                  languageCode: locale.languageCode)
                              .nativeDisplayLanguage
                              .capitalize()),
                        ],
                      ),
                      onTap: () => setThemeMode(locale));
                })),
          ),
        )
      ],
    );
  }
}
