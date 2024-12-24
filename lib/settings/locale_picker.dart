import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(builder: (context, localeProvider, _) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.language,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                                groupValue: localeProvider.locale,
                                onChanged: (value) =>
                                    localeProvider.locale = value),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.system),
                          ],
                        ),
                        onTap: () => localeProvider.locale = null,
                      );
                    }
                    final locale = AppLocalizations.supportedLocales[index - 1];
                    return ListTile(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio(
                                value: locale,
                                groupValue: localeProvider.locale,
                                onChanged: (value) =>
                                    localeProvider.locale = value),
                            const SizedBox(width: 8),
                            Text(Locale.fromSubtags(
                                    languageCode: locale.languageCode)
                                .nativeDisplayLanguage
                                .capitalize()),
                          ],
                        ),
                        onTap: () => localeProvider.locale = locale);
                  })),
            ),
          )
        ],
      );
    });
  }
}
