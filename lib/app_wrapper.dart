import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' hide Consumer;
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/components/bottom_bar.dart';
import 'package:via_mallorca/components/bottom_sheets/pending_notifications.dart';
import 'package:via_mallorca/components/settings_popup.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/screens/map/map_view.dart';
import 'package:via_mallorca/screens/nearby/nearby_view.dart';
import 'package:via_mallorca/screens/routes/routes_view.dart';
import 'package:via_mallorca/screens/stations/stations_view.dart';

class AppWrapper extends ConsumerWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    return Consumer<NotificationsProvider>(
        builder: (context, notifications, value) {
      return Scaffold(
        appBar: ViaAppBar(title: "Via Mallorca", actions: [
          if (notifications.pendingNotifications.isNotEmpty)
            IconButton(
                onPressed: () => {
                      notifications.reloadNotifications(),
                      showModalBottomSheet(
                          showDragHandle: true,
                          context: context,
                          builder: (context) => NotificationsView())
                    },
                icon: Icon(Icons.notifications)),
          SettingsPopup(),
        ]),
        bottomNavigationBar: const BottomNavigation(),
        body: IndexedStack(
          index: currentIndex,
          children: [
            NearbyStops(),
            MapScreen(),
            StationsScreen(),
            RoutesScreen()
          ],
        ),
      );
    });
  }
}
