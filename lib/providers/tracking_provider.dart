import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// A provider class for tracking bus locations and information.
class TrackingProvider extends ChangeNotifier {
  LatLng? currentLocation;
  RouteStationInfo? routeStationInfo;
  StreamSubscription? _locationStream;
  int? currentSpeed;
  int? trackingTripId;
  LineType? lineType;
  String? routeCode;
  List<StationOnRoute>? stationsOnRoute;

  int? trackingFromStation;

  StreamSubscription? _connectivitySubscription;

  /// Starts tracking the bus with the given [tripId] and [lineCode].
  /// Optionally, an [initialCoords] can be provided to set the initial location.
  Future<void> startTracking(int tripId, String lineCode, LatLng initialCoords,
      int trackingFrom) async {
    // Properly clean up existing connections first
    await stopTracking();

    trackingFromStation = trackingFrom;
    trackingTripId = tripId;
    currentLocation = initialCoords;

    if (_locationStream != null) {
      _locationStream!.cancel();
    }

    if (_connectivitySubscription != null) {
      _connectivitySubscription!.cancel();
    }

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((state) async {
      if (state.contains(ConnectivityResult.none)) {
        _locationStream?.pause();
      } else {
        _locationStream?.resume();
        // Consider re-establishing the WebSocket connection if paused for too long
        if (_locationStream?.isPaused ?? false) {
          stopTracking();
          await startTracking(
              tripId, lineCode, currentLocation!, trackingFromStation!);
        }
      }
    });

    trackingFromStation = trackingFrom;

    trackingTripId = tripId;
    currentLocation = initialCoords;

    RouteLine routeLine = await RouteLine.getLine(lineCode);
    lineType = routeLine.type;
    routeCode = routeLine.code;

    Stream locationStream = await LocationWebSocket.locationStream(tripId);
    _locationStream = locationStream.listen((location) {
      var action = LocationWebSocket.locationParser(jsonDecode(location));
      if (action is BusPosition) {
        currentLocation = LatLng(action.lat, action.long);
        currentSpeed = action.speed.round();
        notifyListeners();
      }
      if (action is RouteStationInfo) {
        routeStationInfo = action;
        stationsOnRoute = action.stops;
        notifyListeners();
      }
      if (action is ConnectionClose) {
        stopTracking();
        notifyListeners();
      }
    });
  }

  void pause() {
    _locationStream?.pause();
  }

  void resume() {
    if (_locationStream != null) {
      // Always restart the tracking when resuming the app
      if (trackingTripId != null &&
          routeCode != null &&
          currentLocation != null &&
          trackingFromStation != null) {
        startTracking(trackingTripId!, routeCode!, currentLocation!,
            trackingFromStation!);
      }
    }
  }

  /// Stops tracking the bus.
  Future<void> stopTracking() async {
    await _locationStream?.cancel();
    _locationStream = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    trackingTripId = null;
    trackingFromStation = null;
    currentLocation = null;
    stationsOnRoute = null;
    notifyListeners();
  }
}
