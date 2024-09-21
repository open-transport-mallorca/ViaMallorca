import 'package:flutter/material.dart';

/// A provider class for managing the theme mode in the application.
class ThemeProvider with ChangeNotifier {
  /// The currently selected theme mode.
  ThemeMode selectedThemeMode;

  /// Constructs a new instance of the [ThemeProvider] class with the specified [selectedThemeMode].
  ThemeProvider({required this.selectedThemeMode});

  /// Sets the selected theme mode to the specified [themeMode] and notifies listeners.
  void setSelectedThemeMode(ThemeMode themeMode) {
    selectedThemeMode = themeMode;
    notifyListeners();
  }
}
