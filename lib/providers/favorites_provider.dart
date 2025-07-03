import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<String> _favoriteStations = [];
  List<String> get favoriteStations => _favoriteStations;

  final QuickActions _quickActions = QuickActions();

  FavoritesProvider() {
    _loadFavoriteStations();
  }

  Future<void> setQuickTiles() async {
    final cachedStations = await CacheManager.getAllStations();
    final recentStations = _favoriteStations.reversed.take(4).toList();

    final shortcuts = recentStations.map((stationId) {
      final station =
          cachedStations.firstWhere((s) => s.code.toString() == stationId);
      return ShortcutItem(
        type: 'station_$stationId',
        localizedTitle: station.name,
        icon: 'ic_station',
      );
    }).toList();

    _quickActions.setShortcutItems(shortcuts);
  }

  Future<void> _loadFavoriteStations() async {
    final stations = await LocalStorageApi.getFavoriteStations();
    _favoriteStations.clear();
    _favoriteStations.addAll(stations);
    await setQuickTiles(); // Update quick tiles on load
    notifyListeners();
  }

  void addFavoriteStation(String stationId) {
    if (!_favoriteStations.contains(stationId)) {
      _favoriteStations.add(stationId);
      LocalStorageApi.setFavoriteStations(_favoriteStations);
      setQuickTiles(); // Update quick tiles on change
      notifyListeners();
    }
  }

  void removeFavoriteStation(String stationId) {
    if (_favoriteStations.contains(stationId)) {
      _favoriteStations.remove(stationId);
      LocalStorageApi.setFavoriteStations(_favoriteStations);
      setQuickTiles(); // Update quick tiles on change
      notifyListeners();
    }
  }

  bool isFavoriteStation(String stationId) {
    return _favoriteStations.contains(stationId);
  }
}
