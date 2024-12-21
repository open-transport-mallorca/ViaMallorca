import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';

/// A provider class for managing the theme mode in the application.
class ThemeProvider with ChangeNotifier {
  /// Constructs a new instance of the [ThemeProvider] class with the specified [themeMode].
  ThemeProvider();

  ThemeMode get themeMode => LocalStorageApi.getThemeMode();

  /// Sets the selected theme mode to the specified [themeMode] and notifies listeners.
  set themeMode(ThemeMode selectedMode) {
    LocalStorageApi.setThemeMode(selectedMode);
    notifyListeners();
  }
}
