import 'package:flutter/material.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class TimelineSheetViewModel extends ChangeNotifier {
  List<Station>? _stations;
  List<Station>? get stations => _stations;

  bool _isLoadingStations = true;
  bool get isLoadingStations => _isLoadingStations;

  Future<void> loadStations() async {
    if (_stations != null) return; // Avoid reloading
    _isLoadingStations = true;
    notifyListeners();

    try {
      _stations = await CacheManager.getAllStations();
    } finally {
      _isLoadingStations = false;
      // notifyListeners() is only called if the object is still valid
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
