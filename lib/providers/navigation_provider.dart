import 'package:flutter/material.dart';

/// A provider class for managing the navigation state.
///
/// This class extends the [ChangeNotifier] class and provides a way to keep track of the current index
/// for navigation purposes. It notifies its listeners whenever the index is updated.
class NavigationProvider extends ChangeNotifier {
  int currentIndex = 0;

  /// Sets the current index to the given [index] and notifies the listeners.
  void setIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }
}
