import 'dart:io';
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
import 'package:via_mallorca/screens/nearby.dart';
import 'package:via_mallorca/screens/routes.dart';
import 'package:via_mallorca/screens/stations.dart';
import 'package:via_mallorca/screens/map.dart';
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
    final theme = LocalStorageApi.getThemeMode();
    Locale? locale = LocalStorageApi.getLocale();

    /// Change the language to Ukrainian if the device locale is Russian
    /// Designed specifically to annoy russians and keep them away
    /// from using the app if they're annoyed by the Ukrainian language
    ///
    /// Added by @YarosMallorca
    if (locale == null && Platform.localeName.contains("ru")) {
      locale = const Locale("uk");
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => MapProvider()),
        ChangeNotifierProvider(create: (context) => TrackingProvider()),
        ChangeNotifierProvider(
            create: (context) => ThemeProvider(selectedThemeMode: theme)),
        ChangeNotifierProvider(
            create: (context) => LocaleProvider(locale: locale)),
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
            themeMode: themeProvider.selectedThemeMode,
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
                    LinesScreen()
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
