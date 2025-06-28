import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class DepartureNotificationViewModel extends ChangeNotifier {
  DepartureNotificationViewModel(this.departure) {
    departureInMinutes =
        departure.estimatedArrival.difference(DateTime.now()).inMinutes;
    timeBeforeDeparture = 5;
  }

  final Departure departure;

  late int departureInMinutes;
  late int timeBeforeDeparture;

  void setTimeBeforeDeparture(int value) {
    if (value != timeBeforeDeparture) {
      timeBeforeDeparture = value;
      notifyListeners();
    }
  }
}
