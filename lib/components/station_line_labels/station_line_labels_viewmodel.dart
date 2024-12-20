import 'package:flutter/material.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationViewModel extends ChangeNotifier {
  final Station station;

  StationViewModel(this.station);

  List<RouteLine>? _cachedLines;

  /// Returns the active lines that pass through the station.
  List<RouteLine> get activeLines =>
      (_cachedLines ?? []).where((line) => line.active).toList();

  /// Returns whether the data has been loaded.
  bool get isDataLoaded => _cachedLines != null;

  /// Loads the lines that pass through the
  /// station from the API or cache.
  Future<void> loadLines() async {
    if (_cachedLines != null) return;

    try {
      final cached = await CacheManager.getLines(station.code);
      _cachedLines =
          cached.isNotEmpty ? cached : await Station.getLines(station.code);
      CacheManager.setLines(station.code, _cachedLines!);
    } finally {
      notifyListeners();
    }
  }
}
