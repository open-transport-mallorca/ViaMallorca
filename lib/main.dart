import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/app_wrapper.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/theme_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/utils/legacy_map_cache_cleanup.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageApi.init();
  await CacheManager.init();
  await NotificationApi.init();

  final details = await NotificationApi.notificationsPlugin
      .getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp ?? false) {
    final payload = details!.notificationResponse?.payload;
    if (payload != null) {
      NotificationApi.pendingPayload = payload;
    }
  }

  /// Configures flutter_map's built-in tile cache. Must happen before the map
  /// loads its first tile, otherwise the defaults are locked in.
  ///
  /// [overrideFreshAge] is what makes the map usable offline: without it, tiles
  /// are only served from disk while the server's own `max-age` holds, and once
  /// stale they are re-requested rather than reused. OSM tiles for a single
  /// island barely change, so a month of staleness is a fine trade.
  BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 200 * 1024 * 1024,
    overrideFreshAge: const Duration(days: 30),
  );

  unawaited(clearLegacyMapCaches());

  runApp(ViaMallorca());
}

class ViaMallorca extends StatelessWidget {
  const ViaMallorca({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => MapProvider()),
        ChangeNotifierProvider(create: (context) => TrackingProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => NotificationsProvider()),
      ],
      child: DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
        return Consumer2<ThemeProvider, LocaleProvider>(
          builder: (context, themeProvider, localeProvider, _) => MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,

              /// Not using dynamic schemes directly because of an issue with the
              /// dynamicColor package.
              /// https://github.com/material-foundation/flutter-packages/issues/649
              theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: lightDynamic?.primary ?? Colors.cyan)),
              darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: darkDynamic?.primary ?? Colors.cyan,
                      brightness: Brightness.dark),
                  brightness: Brightness.dark),
              themeMode: themeProvider.themeMode,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: localeProvider.locale,
              home: AppWrapper()),
        );
      }),
    );
  }
}
