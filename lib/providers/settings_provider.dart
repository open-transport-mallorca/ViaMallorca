import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';

/// The app-wide preferences that screens read while building.
///
/// Held in one place so that changing one on the settings page redraws
/// everything that depends on it, rather than only taking effect on the next
/// visit to the affected screen.
class SettingsProvider extends ChangeNotifier {
  DistanceUnits _distanceUnits = LocalStorageApi.getDistanceUnits();
  int _nearbyStopCount = LocalStorageApi.getNearbyStopCount();
  int _notificationLeadTime = LocalStorageApi.getNotificationLeadTime();
  bool _showDischargeOnlyWarning = LocalStorageApi.showDischargeOnlyWarning();
  bool _keepScreenOnWhileTracking = LocalStorageApi.keepScreenOnWhileTracking();
  int _startupTab = LocalStorageApi.getStartupTab(NavigationProvider.tabCount);

  /// The smallest and largest number of stops the nearby screen may list.
  static const int minNearbyStopCount = 5;
  static const int maxNearbyStopCount = 30;

  /// The bounds the departure reminder picker allows, and so the bounds the
  /// default has to stay inside to be usable as a starting point.
  static const int minNotificationLeadTime = 2;
  static const int maxNotificationLeadTime = 60;

  DistanceUnits get distanceUnits => _distanceUnits;
  int get nearbyStopCount => _nearbyStopCount;
  int get notificationLeadTime => _notificationLeadTime;
  bool get showDischargeOnlyWarning => _showDischargeOnlyWarning;
  bool get keepScreenOnWhileTracking => _keepScreenOnWhileTracking;
  int get startupTab => _startupTab;

  set distanceUnits(DistanceUnits value) {
    if (value == _distanceUnits) return;
    _distanceUnits = value;
    LocalStorageApi.setDistanceUnits(value);
    notifyListeners();
  }

  set nearbyStopCount(int value) {
    final clamped = value.clamp(minNearbyStopCount, maxNearbyStopCount);
    if (clamped == _nearbyStopCount) return;
    _nearbyStopCount = clamped;
    LocalStorageApi.setNearbyStopCount(clamped);
    notifyListeners();
  }

  set notificationLeadTime(int value) {
    final clamped =
        value.clamp(minNotificationLeadTime, maxNotificationLeadTime);
    if (clamped == _notificationLeadTime) return;
    _notificationLeadTime = clamped;
    LocalStorageApi.setNotificationLeadTime(clamped);
    notifyListeners();
  }

  set showDischargeOnlyWarning(bool value) {
    if (value == _showDischargeOnlyWarning) return;
    _showDischargeOnlyWarning = value;
    LocalStorageApi.setShowDischargeOnlyWarning(value);
    notifyListeners();
  }

  set keepScreenOnWhileTracking(bool value) {
    if (value == _keepScreenOnWhileTracking) return;
    _keepScreenOnWhileTracking = value;
    LocalStorageApi.setKeepScreenOnWhileTracking(value);
    notifyListeners();
  }

  set startupTab(int value) {
    final clamped = value.clamp(0, NavigationProvider.tabCount - 1);
    if (clamped == _startupTab) return;
    _startupTab = clamped;
    LocalStorageApi.setStartupTab(clamped);
    notifyListeners();
  }
}
