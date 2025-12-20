import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:via_mallorca/extensions/capitalize_string.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:locale_names/locale_names.dart';

class LocalePicker extends ConsumerWidget {
  const LocalePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.language,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: RadioGroup<Locale?>(
            groupValue: locale,
            onChanged: (value) =>
                ref.read(localeProvider.notifier).setLocale(value),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // System locale
                  ListTile(
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Radio<Locale?>(value: null),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.system),
                      ],
                    ),
                    onTap: () =>
                        ref.read(localeProvider.notifier).setLocale(null),
                  ),

                  // Supported locales
                  ...AppLocalizations.supportedLocales.map((locale) {
                    return ListTile(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<Locale?>(value: locale),
                          const SizedBox(width: 8),
                          Text(
                            Locale.fromSubtags(
                              languageCode: locale.languageCode,
                            ).nativeDisplayLanguage.capitalize(),
                          ),
                        ],
                      ),
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLocale(locale),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
