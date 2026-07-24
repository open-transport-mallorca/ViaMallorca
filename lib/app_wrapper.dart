import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/components/bottom_bar.dart';
import 'package:via_mallorca/components/bottom_sheets/pending_notifications.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/news_provider.dart';
import 'package:via_mallorca/providers/settings_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/warnings_provider.dart';
import 'package:via_mallorca/screens/news/news_view.dart';
import 'package:via_mallorca/screens/warnings/warnings_view.dart';
import 'package:via_mallorca/screens/map/map_view.dart';
import 'package:via_mallorca/screens/nearby/nearby_view.dart';
import 'package:via_mallorca/screens/routes/routes_view.dart';
import 'package:via_mallorca/screens/settings/settings_view.dart';
import 'package:via_mallorca/screens/stations/stations_view.dart';

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(builder: (context, navProvider, _) {
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
            const _NewsAction(),
            const _WarningsAction(),
            IconButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen())),
                icon: const Icon(Icons.settings)),
          ]),
          bottomNavigationBar: const BottomNavigation(),
          body: IndexedStack(
            index: navProvider.currentIndex,
            children: [
              NearbyStops(),
              MapScreen(),
              StationsScreen(),
              RoutesScreen()
            ],
          ),
        );
      });
    });
  }
}

/// Opens the news feed, marked when there is anything unread.
///
/// A plain dot rather than a count: news has no per-line data to scope a number
/// to, so on a first launch every item is unread and a count would just read
/// "20". The dot signals there is something new without shouting a figure.
class _NewsAction extends StatefulWidget {
  const _NewsAction();

  @override
  State<_NewsAction> createState() => _NewsActionState();
}

class _NewsActionState extends State<_NewsAction> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NewsProvider>().load(Localizations.localeOf(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsProvider>(
      builder: (context, news, _) {
        if (news.news.isEmpty) return const SizedBox.shrink();
        final showBadge = context.watch<SettingsProvider>().showServiceBadges;
        return IconButton(
          tooltip: AppLocalizations.of(context)!.news,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewsScreen()),
          ),
          icon: Badge(
            isLabelVisible: showBadge && news.unreadCount > 0,
            child: const Icon(Icons.feed_outlined),
          ),
        );
      },
    );
  }
}

/// Opens the service warnings, badged with how many unread ones concern a line
/// the user has favourited.
///
/// Loads the feed on first build rather than on first visit, since the point of
/// the badge is to tell the user about a disruption they have not gone looking
/// for. Counting only their own lines is what keeps that from being a permanent
/// unread marker - the operator publishes for the whole island.
class _WarningsAction extends StatefulWidget {
  const _WarningsAction();

  @override
  State<_WarningsAction> createState() => _WarningsActionState();
}

class _WarningsActionState extends State<_WarningsAction> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WarningsProvider>().load(Localizations.localeOf(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WarningsProvider, FavoritesProvider>(
      builder: (context, warnings, favorites, _) {
        if (warnings.warnings.isEmpty) return const SizedBox.shrink();
        final showBadge = context.watch<SettingsProvider>().showServiceBadges;
        final unread = warnings.unreadCountForLines(favorites.favoriteRoutes);
        return IconButton(
          tooltip: AppLocalizations.of(context)!.warnings,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WarningsScreen()),
          ),
          icon: Badge.count(
            count: unread,
            isLabelVisible: showBadge && unread > 0,
            child: const Icon(Icons.warning_amber_rounded),
          ),
        );
      },
    );
  }
}
