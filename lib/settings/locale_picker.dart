import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/extensions/capitalize_string.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:locale_names/locale_names.dart';

/// A widget that allows the user to pick a locale.
///
/// Sizes itself to its content, so as a bottom sheet it is only as tall as the
/// list of languages needs, and scrolls instead of growing when that list is
/// taller than the screen allows.
class LocalePicker extends StatelessWidget {
  const LocalePicker({super.key});

  /// A null entry stands for the system locale, and leads the list.
  static final List<Locale?> _options = [
    null,
    ...AppLocalizations.supportedLocales,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppLocalizations.of(context)!.language,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: RadioGroup<Locale?>(
                groupValue: localeProvider.locale,
                onChanged: (value) {
                  localeProvider.locale = value;
                  Navigator.of(context).pop();
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final locale = _options[index];
                    return RadioListTile<Locale?>(
                      value: locale,
                      title: Text(_label(context, locale)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  /// The language's name in its own language, or the system label for null.
  static String _label(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context)!.system;
    return Locale.fromSubtags(languageCode: locale.languageCode)
        .nativeDisplayLanguage
        .capitalize();
  }
}
