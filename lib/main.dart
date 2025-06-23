import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/app_wrapper.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/theme_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

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

  /// Switched to another caching mechanism.
  /// This is here to delete the cached tiles from the old caching mechanism.
  try {
    await FMTCObjectBoxBackend().initialise();
    await FMTCStore('mapStore').manage.reset();
  } catch (e) {
    debugPrint("Error deleting old cache: $e");
  }

  runApp(ViaMallorca());
}

class ViaMallorca extends StatelessWidget {
  const ViaMallorca({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
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
