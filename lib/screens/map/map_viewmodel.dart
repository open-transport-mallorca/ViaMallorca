import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/location.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:flutter/widgets.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final bool _havePermission = false;
  bool get havePermission => _havePermission;
  List<Station> _cachedStations = [];
  List<Station> get cachedStations => _cachedStations;
  String? cacheDirectory;
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

    LocationPermission locationPermission =
        await LocationApi().permissionStatus();

    if (locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always) {
      // Delay the location update to ensure the map is fully loaded
      Future.delayed(
        const Duration(seconds: 2),
        () => context.mounted
            ? context.read<MapProvider>().moveToCurrentLocation(context)
            : null,
      );
    }

    cacheDirectory = await _getCachePath();
    notifyListeners();
  }

  Future<String> _getCachePath() async {
    final cacheDirectory = await getTemporaryDirectory();
    return cacheDirectory.path;
  }
}
