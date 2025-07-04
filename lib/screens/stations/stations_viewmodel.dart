import 'package:flutter/material.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';

class StationsViewModel extends ChangeNotifier {
  final FavoritesProvider favoritesProvider;

  final TextEditingController searchController = TextEditingController();
  List<Station> cachedStations = [];
  List<Station> searchResults = [];
  bool onlyFavourites = false;
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StationsViewModel(this.favoritesProvider) {
    searchController.addListener(_onSearchTextChanged);
  }

  Future<void> loadStations() async {
    cachedStations = await CacheManager.getAllStations();
    if (cachedStations.isEmpty) {
      cachedStations = await Station.getAllStations();
      CacheManager.setAllStations(cachedStations);
    }
    _isLoading = false;
    notifyListeners();
  }

  void toggleFavouritesFilter(bool value) {
    onlyFavourites = value;
    notifyListeners();
  }

  void _onSearchTextChanged() {
    if (onlyFavourites) onlyFavourites = false;
    searchResults = cachedStations.where((station) {
      final normalizedQuery =
          searchController.text.toLowerCase().removePunctuation();
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

  List<Station> get filteredStations {
    if (onlyFavourites) {
      return cachedStations
          .where((station) => favoritesProvider.favoriteStations
              .contains(station.code.toString()))
          .toList();
    }
    return searchResults.isEmpty && searchController.text.isEmpty
        ? cachedStations
        : searchResults;
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchTextChanged);
    searchController.dispose();
    super.dispose();
  }
}
