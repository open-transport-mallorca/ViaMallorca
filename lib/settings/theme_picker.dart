import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/theme_provider.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
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
              // Light
              _buildThemeButton(context,
                  label: AppLocalizations.of(context)!.light,
                  icon: Icons.light_mode,
                  isSelected: theme == ThemeMode.light,
                  onPressed: () => ref
                      .read(themeProvider.notifier)
                      .setThemeMode(ThemeMode.light)),

              // Dark
              _buildThemeButton(context,
                  label: AppLocalizations.of(context)!.dark,
                  icon: Icons.dark_mode,
                  isSelected: theme == ThemeMode.dark,
                  onPressed: () => ref
                      .read(themeProvider.notifier)
                      .setThemeMode(ThemeMode.dark)),

              // System
              _buildThemeButton(context,
                  label: AppLocalizations.of(context)!.system,
                  icon: Icons.brightness_4,
                  isSelected: theme == ThemeMode.system,
                  onPressed: () => ref
                      .read(themeProvider.notifier)
                      .setThemeMode(ThemeMode.system)),
            ],
          ),
          const SizedBox(height: 16)
        ],
      ),
    );
  }

  Widget _buildThemeButton(BuildContext context,
      {required String label,
      required IconData icon,
      required bool isSelected,
      required VoidCallback onPressed}) {
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
