import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<String> _favoriteStations = [];
  List<String> get favoriteStations => _favoriteStations;

  final List<String> _favoriteRoutes = [];
  List<String> get favoriteRoutes => _favoriteRoutes;

  final QuickActions _quickActions = QuickActions();

  FavoritesProvider() {
    _loadFavoriteStations();
    _loadFavoriteRoutes();
  }

  Future<void> setQuickTiles() async {
    final cachedStations = await CacheManager.getAllStations();
    final recentStations = _favoriteStations.reversed.take(4).toList();

    if (cachedStations.isEmpty || recentStations.isEmpty) return;

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

  void _loadFavoriteStations() {
    final stations = LocalStorageApi.getFavoriteStations();
    _favoriteStations.clear();
    _favoriteStations.addAll(stations);
    notifyListeners();
  }

  void _loadFavoriteRoutes() {
    final routes = LocalStorageApi.getFavoriteRoutes();
    _favoriteRoutes.clear();
    _favoriteRoutes.addAll(routes);
    notifyListeners();
  }

  void addFavoriteRoute(String routeId) {
    if (!_favoriteRoutes.contains(routeId)) {
      _favoriteRoutes.add(routeId);
      LocalStorageApi.setFavoriteRoutes(_favoriteRoutes);
      notifyListeners();
    }
  }

  void removeFavoriteRoute(String routeId) {
    if (_favoriteRoutes.contains(routeId)) {
      _favoriteRoutes.remove(routeId);
      LocalStorageApi.setFavoriteRoutes(_favoriteRoutes);
      notifyListeners();
    }
  }

  bool isFavoriteRoute(String routeId) {
    return _favoriteRoutes.contains(routeId);
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
