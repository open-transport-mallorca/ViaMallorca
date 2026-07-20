import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';

/// Marks the start of a sector's run of routes in [RoutesViewModel.groupedRoutes].
///
/// [sector] is the operator's own value — a number like `"300"`, `"Metro"`,
/// `"Tren"`, or null for lines it files under nothing.
class SectorHeader {
  const SectorHeader(this.sector);

  final String? sector;
}

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
      _cachedLines = await RouteLinesApi.getAllLines();
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

  /// [filteredRoutes] laid out for a flat list, with a [SectorHeader] opening
  /// each group.
  ///
  /// The operator files every line under a sector, which splits an otherwise
  /// undifferentiated list of 80-odd routes into a handful of runs.
  List<Object> get groupedRoutes {
    final bySector = <String?, List<RouteLine>>{};
    for (final route in filteredRoutes) {
      bySector.putIfAbsent(route.sector, () => []).add(route);
    }

    final sectors = bySector.keys.toList()
      ..sort((a, b) {
        final rankA = _sectorRank(a);
        final rankB = _sectorRank(b);
        if (rankA != rankB) return rankA.compareTo(rankB);
        final numA = int.tryParse(a ?? '');
        final numB = int.tryParse(b ?? '');
        if (numA != null && numB != null) return numA.compareTo(numB);
        return (a ?? '').compareTo(b ?? '');
      });

    return [
      for (final sector in sectors) ...[
        SectorHeader(sector),
        ...bySector[sector]!,
      ],
    ];
  }

  /// Numbered sectors first, then the rail modes, then anything unfiled.
  static int _sectorRank(String? sector) {
    if (sector == null) return 3;
    if (int.tryParse(sector) != null) return 0;
    if (sector == 'Metro') return 1;
    if (sector == 'Tren') return 2;
    return 3;
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchTextChanged);
    searchController.dispose();
    super.dispose();
  }
}
