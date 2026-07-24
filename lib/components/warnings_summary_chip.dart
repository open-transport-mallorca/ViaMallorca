import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/settings_provider.dart';
import 'package:via_mallorca/providers/warnings_provider.dart';
import 'package:via_mallorca/screens/warnings/warnings_view.dart';

/// One line summarising which of the departing lines have a warning against
/// them, above a list of departures.
///
/// Sits above the list rather than on each card: a stop served by a disrupted
/// line shows that line many times over, and a badge per departure repeats the
/// same sentence down the whole screen.
class WarningsSummaryChip extends StatelessWidget {
  const WarningsSummaryChip({super.key, required this.lineCodes});

  /// The line codes appearing in the list below, in the order they appear.
  final List<String> lineCodes;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsProvider>().showDepartureWarnings) {
      return const SizedBox.shrink();
    }
    return Consumer<WarningsProvider>(
      builder: (context, provider, _) {
        final warned = provider.warnedLines(lineCodes);
        if (warned.isEmpty) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => WarningsScreen(lineFilter: warned)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: scheme.onErrorContainer),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context)!
                            .warningsForLine(warned.join(', ')),
                        style: TextStyle(
                            fontSize: 13, color: scheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: scheme.onErrorContainer),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
