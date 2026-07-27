import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// View model for the station details screen.
///
/// Handles the upcoming departures. The lines serving the stop are loaded
/// independently by the reused [StationLineLabels] widget.
class StationDetailsViewModel extends ChangeNotifier {
  StationDetailsViewModel(this.station);

  final Station station;

  static const int numberOfDepartures = 10;

  List<Departure>? departures;
  bool departuresError = false;

  bool _isDisposed = false;

  Future<void> initialize() async {
    await fetchDepartures();
  }

  Future<void> fetchDepartures() async {
    try {
      departures = await DeparturesApi.getDepartures(
        stationCode: station.code,
        numberOfDepartures: numberOfDepartures,
      );
      departuresError = false;
    } catch (_) {
      departuresError = true;
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
