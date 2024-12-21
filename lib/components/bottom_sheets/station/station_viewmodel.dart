import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationSheetViewModel extends ChangeNotifier {
  final Station station;

  StationSheetViewModel(this.station);

  bool isFavourite = false;
  List<Departure>? departures;
  bool isLoading = true;
  bool hasError = false;
  final int numberOfDepartures = 10;

  Future<void> initialize() async {
    await _loadFavouriteStatus();
    await fetchDepartures();
  }

  Future<void> _loadFavouriteStatus() async {
    final favourites = await LocalStorageApi.getFavouriteStations();
    isFavourite = favourites.contains(station.code.toString());
    notifyListeners();
  }

  Future<void> toggleFavourite() async {
    final favourites = await LocalStorageApi.getFavouriteStations();

    if (isFavourite) {
      favourites.remove(station.code.toString());
    } else {
      favourites.add(station.code.toString());
    }
    await LocalStorageApi.setFavouriteStations(favourites);
    isFavourite = !isFavourite;
    notifyListeners();
  }

  Future<void> fetchDepartures() async {
    try {
      isLoading = true;
      hasError = false;
      notifyListeners();

      departures = await Departures.getDepartures(
        stationCode: station.code,
        numberOfDepartures: numberOfDepartures,
      );
    } catch (e) {
      hasError = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
