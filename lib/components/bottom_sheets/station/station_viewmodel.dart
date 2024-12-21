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
    if (!_isDisposed) {
      notifyListeners();
    }
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
    if (!_isDisposed) {
      notifyListeners();
    }
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
