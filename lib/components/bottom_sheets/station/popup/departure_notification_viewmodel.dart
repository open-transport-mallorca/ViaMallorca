import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/providers/settings_provider.dart';

class DepartureNotificationViewModel extends ChangeNotifier {
  /// [defaultLeadTime] is the user's preferred number of minutes' warning. It
  /// is only a starting point: a departure that is sooner than that cannot be
  /// given that much notice, so it is brought down to what fits.
  DepartureNotificationViewModel(this.departure, int defaultLeadTime) {
    departureInMinutes =
        departure.estimatedArrival.difference(DateTime.now()).inMinutes;
    timeBeforeDeparture =
        maxLeadTime <= SettingsProvider.minNotificationLeadTime
            ? SettingsProvider.minNotificationLeadTime
            : defaultLeadTime.clamp(
                SettingsProvider.minNotificationLeadTime, maxLeadTime);
  }

  final Departure departure;

  late int departureInMinutes;
  late int timeBeforeDeparture;

  /// The most warning this departure still leaves room for.
  ///
  /// A reminder has to land before the bus does, so the picker stops one minute
  /// short of the departure itself.
  int get maxLeadTime => departureInMinutes - 1;

  void setTimeBeforeDeparture(int value) {
    if (value != timeBeforeDeparture) {
      timeBeforeDeparture = value;
      notifyListeners();
    }
  }
}
