import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/theme_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

/// A row of buttons that allows the user to pick a theme.
///
/// The buttons share the width they are given rather than being fixed size, so
/// the row sits inline on the settings page without overflowing on narrow
/// screens or in languages with long labels.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, _) {
      final localizations = AppLocalizations.of(context)!;
      return Row(
        children: [
          Expanded(
            child: _ThemeButton(
              label: localizations.light,
              icon: Icons.light_mode,
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onPressed: () => themeProvider.themeMode = ThemeMode.light,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeButton(
              label: localizations.dark,
              icon: Icons.dark_mode,
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onPressed: () => themeProvider.themeMode = ThemeMode.dark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeButton(
              label: localizations.system,
              icon: Icons.brightness_4,
              isSelected: themeProvider.themeMode == ThemeMode.system,
              onPressed: () => themeProvider.themeMode = ThemeMode.system,
            ),
          ),
        ],
      );
    });
  }
}

/// A single theme option, highlighted with a border while it is the active one.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: colors.secondary, width: 4)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.onSecondaryContainer),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
