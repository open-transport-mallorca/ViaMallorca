import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API for local storage.
///
/// This class is used to store data locally on the device.
/// Used for user settings, and tracking user preferences/viewed content
class LocalStorageApi {
  static SharedPreferences? _preferences;

  /// Initialize the local storage API.
  ///
  /// This method should be called before any other method in this class.
  /// Usually called in the main method.
  static init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  /// Retrieves the current theme mode from the local storage.
  ///
  /// If the theme mode is not set in the local storage,
  /// it defaults to `ThemeMode.system`.
  ///
  /// Returns the current theme mode as a [ThemeMode] enum value.
  static ThemeMode getThemeMode() {
    final themeMode = _preferences?.getString('themeMode');
    return themeMode != null
        ? ThemeMode.values.firstWhere(
            (mode) => mode.name == themeMode,
            orElse: () => ThemeMode.system,
          )
        : ThemeMode.system;
  }

  /// Sets the theme mode in the local storage.
  ///
  /// The [themeMode] parameter specifies the theme mode to be set.
  /// It should be one of the values from the [ThemeMode] enum.
  /// The theme mode is stored as a string in the local storage.
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final String mode = themeMode.name;
    await _preferences!.setString('themeMode', mode);
  }

  /// Retrieves the current locale from the shared preferences.
  ///
  /// Returns the current locale as a [Locale] object if it exists in the shared preferences.
  /// If the locale is set to 'auto' or is null, it returns null.
  ///
  /// Null means the app should use the system locale.
  static Locale? getLocale() {
    final locale = _preferences!.getString('locale');
    if (locale == 'auto' || locale == null) {
      return null;
    } else {
      return Locale(locale);
    }
  }

  /// Sets the locale for the application.
  ///
  /// The [locale] parameter specifies the desired locale to be set.
  /// If [locale] is null, the locale will be set to 'auto'.
  /// The locale is stored in the shared preferences as a string.
  static setLocale(Locale? locale) async {
    await _preferences!.setString('locale', locale?.languageCode ?? 'auto');
  }

  /// Checks if the app is being opened for the first time.
  ///
  /// Returns `true` if the app is being opened for the first time,
  /// otherwise returns `false`.
  static bool openedFirstTime() {
    return _preferences!.getBool('openedFirstTime') ?? true;
  }

  /// Sets the value of 'openedFirstTime' in the local storage.
  ///
  /// This method is used to store the boolean value of 'openedFirstTime' in the local storage.
  /// It takes a boolean parameter 'openedFirstTime' and sets the value in the local storage.
  ///
  /// Example usage:
  /// ```dart
  /// await LocalStorageApi.setOpenedFirstTime(true);
  /// ```
  static Future setOpenedFirstTime(bool openedFirstTime) async {
    await _preferences!.setBool('openedFirstTime', openedFirstTime);
  }

  /// Retrieves the list of shown warnings from the local storage preferences.
  ///
  /// The [warningList] parameter is the list of warnings to filter.
  /// Returns a list of strings representing the shown warnings.
  static List<String> getShownWarnings(List<String> warningList) {
    return _preferences!.getStringList("shownWarnings") ?? [];
  }

  /// Sets the list of shown warnings in the local storage.
  ///
  /// The [warningList] parameter is a list of strings representing the warnings to be stored.
  /// This method uses the shared preferences to store the list of shown warnings.
  /// Returns a Future that completes when the operation is done.
  static Future setShownWarnings(List<String> warningList) async {
    await _preferences!.setStringList("shownWarnings", warningList);
  }

  /// Retrieves the list of shown news from the local storage.
  ///
  /// Returns a list of strings representing the shown news.
  static List<String> getShownNews(List<String> newsList) {
    return _preferences!.getStringList("shownNews") ?? [];
  }

  /// Sets the list of shown news in the local storage.
  ///
  /// [newsList] - A list of strings representing the shown news.
  static Future setShownNews(List<String> newsList) async {
    await _preferences!.setStringList("shownNews", newsList);
  }

  /// Retrieves the list of favourite stations from the local storage.
  ///
  /// Returns a future that completes with a list of strings representing the favourite stations.
  static List<String> getFavoriteStations() {
    return _preferences!.getStringList("favouriteStations") ?? [];
  }

  /// Sets the list of favourite stations in the local storage.
  ///
  /// [favouriteStations] - A list of strings representing the favourite stations.
  static Future setFavoriteStations(List<String> favouriteStations) async {
    await _preferences!.setStringList("favouriteStations", favouriteStations);
  }

  /// Retrieves the list of favourite routes from the local storage.
  ///
  /// Returns a future that completes with a list of strings representing the favourite routes.
  /// If no favourite routes are stored, it returns an empty list.
  static List<String> getFavoriteRoutes() {
    return _preferences!.getStringList("favouriteRoutes") ?? [];
  }

  /// Sets the list of favourite routes in the local storage.
  ///
  /// The [favouriteRoutes] parameter is a list of strings representing the favourite routes.
  static Future setFavoriteRoutes(List<String> favouriteRoutes) async {
    await _preferences!.setStringList("favouriteRoutes", favouriteRoutes);
  }

  /// Whether to use inexact notifications.
  /// This is used only on Android
  static bool useInexactNotifications() {
    return _preferences!.getBool("useInexactNotifications") ?? false;
  }

  /// Sets whether to use inexact notifications.
  ///  This is used only on Android.
  static Future setUseInexactNotifications(bool useInexactNotifications) async {
    await _preferences!
        .setBool("useInexactNotifications", useInexactNotifications);
  }

  /// Retrieves the notification channel from the local storage.
  ///
  ///  Returns the notification channel as a string if it exists,
  /// otherwise returns null.
  static String? getNotificationChannel() {
    return _preferences!.getString("notificationChannel");
  }

  /// Sets the notification channel in the local storage.
  ///
  ///  The [channel] parameter specifies the notification channel to be set.
  static Future setNotificationChannel(String channel) async {
    await _preferences!.setString("notificationChannel", channel);
  }
}
