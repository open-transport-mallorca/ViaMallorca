import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/theme_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

/// A widget that allows the user to pick a theme.
class ThemePicker extends StatefulWidget {
  const ThemePicker({super.key});

  @override
  State<ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<ThemePicker> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, _) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.theme,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildThemeButton(
                    AppLocalizations.of(context)!.light,
                    Icons.light_mode,
                    themeProvider.themeMode == ThemeMode.light,
                    () => themeProvider.themeMode = ThemeMode.light),
                _buildThemeButton(
                    AppLocalizations.of(context)!.dark,
                    Icons.dark_mode,
                    themeProvider.themeMode == ThemeMode.dark,
                    () => themeProvider.themeMode = ThemeMode.dark),
                _buildThemeButton(
                    AppLocalizations.of(context)!.system,
                    Icons.brightness_4,
                    themeProvider.themeMode == ThemeMode.system,
                    () => themeProvider.themeMode = ThemeMode.system),
              ],
            ),
            const SizedBox(height: 16)
          ],
        ),
      );
    });
  }

  /// Builds a theme button with the given label, icon, and onPressed callback.
  Widget _buildThemeButton(
      String label, IconData icon, bool isSelected, VoidCallback onPressed) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.secondary, width: 4)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSecondaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}
