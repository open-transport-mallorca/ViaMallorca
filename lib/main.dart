import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/components/bottom_bar.dart';
import 'package:via_mallorca/components/settings_popup.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/theme_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/screens/nearby/nearby_view.dart';
import 'package:via_mallorca/screens/routes/routes_view.dart';
import 'package:via_mallorca/screens/stations/stations_view.dart';
import 'package:via_mallorca/screens/map/map_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageApi.init();
  await CacheManager.init();
  runApp(const ViaMallorca());
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
      ],
      child: DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
        return Consumer2<ThemeProvider, LocaleProvider>(
          builder: (context, themeProvider, localeProvider, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                colorScheme: lightDynamic ??
                    ColorScheme.fromSeed(seedColor: Colors.cyan)),
            darkTheme: ThemeData(
                colorScheme: darkDynamic ??
                    ColorScheme.fromSeed(
                        seedColor: Colors.cyan, brightness: Brightness.dark),
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
            home: Consumer<NavigationProvider>(
                builder: (context, navProvider, _) {
              return Scaffold(
                appBar: const ViaAppBar(title: "Via Mallorca", actions: [
                  SettingsPopup(),
                ]),
                bottomNavigationBar: const BottomNavigation(),
                body: IndexedStack(
                  index: navProvider.currentIndex,
                  children: const [
                    NearbyStops(),
                    MapScreen(),
                    StationsScreen(),
                    RoutesScreen()
                  ],
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
