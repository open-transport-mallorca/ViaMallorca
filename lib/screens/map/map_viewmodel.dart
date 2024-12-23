import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/cache/cache_manager.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final bool _havePermission = false;
  bool get havePermission => _havePermission;
  List<Station> _cachedStations = [];
  List<Station> get cachedStations => _cachedStations;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _cachedStations = await CacheManager.getAllStations();
    if (_cachedStations.isEmpty) {
      _cachedStations = await Station.getAllStations();
      await CacheManager.setAllStations(_cachedStations);
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume tracking
    } else if (state == AppLifecycleState.paused) {
      // Pause tracking
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
