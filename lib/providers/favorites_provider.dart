import 'package:flutter/material.dart';
import 'package:via_mallorca/apis/local_storage.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<String> _favoriteStations = [];
  List<String> get favoriteStations => _favoriteStations;

  FavoritesProvider() {
    _loadFavoriteStations();
  }

  Future<void> _loadFavoriteStations() async {
    final stations = await LocalStorageApi.getFavoriteStations();
    _favoriteStations.clear();
    _favoriteStations.addAll(stations);
    notifyListeners();
  }

  void addFavoriteStation(String stationId) {
    if (!_favoriteStations.contains(stationId)) {
      _favoriteStations.add(stationId);
      LocalStorageApi.setFavoriteStations(_favoriteStations);
      notifyListeners();
    }
  }

  void removeFavoriteStation(String stationId) {
    if (_favoriteStations.contains(stationId)) {
      _favoriteStations.remove(stationId);
      LocalStorageApi.setFavoriteStations(_favoriteStations);
      notifyListeners();
    }
  }

  bool isFavoriteStation(String stationId) {
    return _favoriteStations.contains(stationId);
  }
}
