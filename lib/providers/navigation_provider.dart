import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';

/// A provider class for managing the navigation state.
///
/// This class extends the [ChangeNotifier] class and provides a way to keep track of the current index
/// for navigation purposes. It notifies its listeners whenever the index is updated.
class NavigationProvider extends ChangeNotifier {
  /// How many destinations the bottom navigation bar has.
  ///
  /// Kept here rather than in the bar itself because the startup tab preference
  /// has to be validated against it before any widget is built.
  static const int tabCount = 4;

  /// Starts on whichever tab the user chose to open the app on.
  int currentIndex = LocalStorageApi.getStartupTab(tabCount);

  /// Sets the current index to the given [index] and notifies the listeners.
  void setIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }
}
