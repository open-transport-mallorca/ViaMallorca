import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/location.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/popups/location_denied_popup.dart';
import 'package:via_mallorca/providers/map_provider.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  List<Station> _cachedStations = [];
  LocationPermission _locationPermission = LocationPermission.denied;
  String? cacheDirectory;
  final StreamController<double?> alignPositionStreamController =
      StreamController<double?>.broadcast();
  AlignOnUpdate alignPositionOnUpdate = AlignOnUpdate.never;

  List<Station> get cachedStations => _cachedStations;
  LocationPermission get locationPermission => _locationPermission;
  String? get cacheDir => cacheDirectory;

  Future<void> initialize(BuildContext context, TickerProvider vsync) async {
    context
        .read<MapProvider>()
        .setMapController(AnimatedMapController(vsync: vsync));
    _cachedStations = await CacheManager.getAllStations();
    if (_cachedStations.isEmpty) {
      _cachedStations = await Station.getAllStations();
      await CacheManager.setAllStations(_cachedStations);
    }

    _locationPermission = await LocationApi.permissionStatus();

    if (_locationPermission == LocationPermission.whileInUse ||
        _locationPermission == LocationPermission.always) {
      // Delay the location update to ensure the map is fully loaded
      Future.delayed(
        const Duration(seconds: 2),
        () => context.mounted ? moveToCurrentLocation(context) : null,
      );
    }

    cacheDirectory = await _getCachePath();
    notifyListeners();
  }

  Future<void> moveToCurrentLocation(BuildContext context) async {
    _locationPermission = await LocationApi.permissionStatus();
    notifyListeners();
    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await LocationApi.requestPermission();
      if ((_locationPermission == LocationPermission.denied ||
              _locationPermission == LocationPermission.deniedForever) &&
          context.mounted) {
        showDialog(
            context: context,
            builder: (context) => const LocationDeniedPopup());
        return;
      }
    } else if (_locationPermission == LocationPermission.deniedForever) {
      if (context.mounted) {
        showDialog(
            context: context,
            builder: (context) => const LocationDeniedPopup());
      }
      return;
    }

    /// This will move the map to the current location
    /// and set the zoom level to 16
    alignPositionStreamController.add(16);
  }

  Future<String> _getCachePath() async {
    final cacheDirectory = await getTemporaryDirectory();
    return cacheDirectory.path;
  }
}
