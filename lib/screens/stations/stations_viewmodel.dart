import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationsViewModel extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();
  List<Station> cachedStations = [];
  List<Station> searchResults = [];
  List<Station>? favourites = [];
  bool onlyFavourites = false;

  Future<void> loadStations() async {
    cachedStations = await CacheManager.getAllStations();
    if (cachedStations.isEmpty) {
      cachedStations = await Station.getAllStations();
      CacheManager.setAllStations(cachedStations);
    }
    favourites = await _getFavouriteStations();
    notifyListeners();
  }

  Future<List<Station>> _getFavouriteStations() async {
    final favouriteCodes = await LocalStorageApi.getFavouriteStations();
    return cachedStations.where((station) {
      return favouriteCodes.contains(station.code.toString());
    }).toList();
  }

  void toggleFavouritesFilter(bool value) {
    onlyFavourites = value;
    notifyListeners();
  }

  void searchStations(String query) {
    searchResults = cachedStations.where((station) {
      final normalizedQuery = query.toLowerCase().removePunctuation();
      return station.name
              .toLowerCase()
              .removePunctuation()
              .contains(normalizedQuery) ||
          station.code
              .toString()
              .toLowerCase()
              .removePunctuation()
              .contains(normalizedQuery) ||
          (station.ref
                  ?.toLowerCase()
                  .removePunctuation()
                  .contains(normalizedQuery) ??
              false);
    }).toList();
    notifyListeners();
  }

  void addFavourite(Station station) async {
    favourites?.insert(0, station);
    await _saveFavourites();
    notifyListeners();
  }

  void removeFavourite(Station station) async {
    favourites?.remove(station);
    await _saveFavourites();
    notifyListeners();
  }

  Future<void> _saveFavourites() async {
    final favouriteCodes =
        favourites?.map((station) => station.code.toString()).toList() ?? [];
    await LocalStorageApi.setFavouriteStations(favouriteCodes);
  }

  List<Station> get filteredStations {
    if (onlyFavourites) {
      return favourites ?? [];
    }
    return searchResults.isEmpty && searchController.text.isEmpty
        ? cachedStations
        : searchResults;
  }
}
