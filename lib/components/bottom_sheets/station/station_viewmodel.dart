import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationSheetViewModel extends ChangeNotifier {
  final Station station;

  StationSheetViewModel(this.station);

  List<Departure>? departures;
  bool isLoading = true;
  bool hasError = false;
  final int numberOfDepartures = 10;

  Future<void> initialize() async {
    await fetchDepartures();
  }

  Future<void> fetchDepartures() async {
    try {
      isLoading = true;
      hasError = false;
      if (!_isDisposed) {
        notifyListeners();
      }

      departures = await Departures.getDepartures(
        stationCode: station.code,
        numberOfDepartures: numberOfDepartures,
      );
    } catch (e) {
      hasError = true;
    } finally {
      isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
