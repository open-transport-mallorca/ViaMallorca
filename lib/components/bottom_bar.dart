import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

class BottomNavigation extends ConsumerWidget {
  const BottomNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(navigationProvider.notifier).setIndex(index);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
            icon: const Icon(Icons.near_me),
            label: AppLocalizations.of(context)!.nearby),
        NavigationDestination(
            icon: const Icon(Icons.map),
            label: AppLocalizations.of(context)!.map),
        NavigationDestination(
            icon: const Icon(Icons.directions_bus),
            label: AppLocalizations.of(context)!.stations),
        NavigationDestination(
            icon: const Icon(Icons.linear_scale_sharp),
            label: AppLocalizations.of(context)!.routes)
      ],
    );
  }
}
