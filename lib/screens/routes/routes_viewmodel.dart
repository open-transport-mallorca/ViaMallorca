import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';

class RoutesViewModel extends ChangeNotifier {
  final FavoritesProvider favoritesProvider;
  final TextEditingController searchController = TextEditingController();

  List<RouteLine> _cachedLines = [];
  bool _isLoading = true;
  List<RouteLine> searchResults = [];
  bool onlyFavourites = false;

  RoutesViewModel(this.favoritesProvider) {
    _initialize();
    searchController.addListener(_onSearchTextChanged);
  }

  bool get isLoading => _isLoading;

  String get searchQuery => searchController.text;

  Future<void> _initialize() async {
    _cachedLines = await CacheManager.getAllLines();
    if (_cachedLines.isEmpty) {
      _cachedLines = await RouteLine.getAllLines();
      CacheManager.setAllLines(_cachedLines);
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
    searchResults = _cachedLines.where((route) {
      final normalizedQuery =
          searchController.text.toLowerCase().removePunctuation();
      return route.name
              .toLowerCase()
              .removePunctuation()
              .contains(normalizedQuery) ||
          route.code
              .toString()
              .toLowerCase()
              .removePunctuation()
              .contains(normalizedQuery);
    }).toList();
    notifyListeners();
  }

  List<RouteLine> get filteredRoutes {
    if (onlyFavourites) {
      return _cachedLines
          .where((route) =>
              favoritesProvider.favoriteRoutes.contains(route.code.toString()))
          .toList();
    }
    return searchResults.isEmpty && searchController.text.isEmpty
        ? _cachedLines
        : searchResults;
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchTextChanged);
    searchController.dispose();
    super.dispose();
  }
}
