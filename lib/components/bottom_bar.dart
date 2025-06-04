import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(builder: (context, navProvider, _) {
      return NavigationBar(
        selectedIndex: navProvider.currentIndex,
        onDestinationSelected: (index) {
          navProvider.setIndex(index);
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
    });
  }
}
