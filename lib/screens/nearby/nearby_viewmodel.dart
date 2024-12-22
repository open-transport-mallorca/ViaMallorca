import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/apis/location.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/utils/station_sort.dart';

class NearbyStopsViewModel extends ChangeNotifier {
  final LocationApi _locationApi = LocationApi();
  LocationPermission _locationPermission = LocationPermission.denied;
  List<Station> _cachedStations = [];
  List<Station> _nearbyStations = [];
  Position? _currentLocation;
  bool _isLoading = false;
  String? _errorMessage;

  LocationPermission get locationPermission => _locationPermission;
  List<Station> get nearbyStations => _nearbyStations;
  Position? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    notifyListeners();

    _locationPermission = await _locationApi.permissionStatus();
    if (_locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse) {
      await loadStations();
    }

    notifyListeners();
  }

  Future<void> loadStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cachedStations = await CacheManager.getAllStations();
      if (_cachedStations.isEmpty) {
        _cachedStations = await Station.getAllStations();
        await CacheManager.setAllStations(_cachedStations);
      }

      _currentLocation = await _locationApi.getCurrentLocation();
      _nearbyStations =
          StationSort.sortByDistance(_cachedStations, _currentLocation!)
              .take(10)
              .toList();
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> requestLocationPermission() async {
    _locationPermission = await _locationApi.requestPermission();
    notifyListeners();

    if (_locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse) {
      await loadStations();
    }
  }
}
