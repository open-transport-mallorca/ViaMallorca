import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// import 'package:via_mallorca/apis/notification.dart';
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
    if (_locationStream != null) {
      _locationStream!.cancel();
    }

    if (_connectivitySubscription != null) {
      _connectivitySubscription!.cancel();
    }

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((state) async {
      _connectivitySubscription?.pause();
      Future.delayed(Duration.zero, () async {
        _connectivitySubscription?.resume();
      });
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
      }
      if (action is ConnectionClose) {
        stopTracking();
      }
    });
  }

  void pause() {
    _locationStream?.pause();
  }

  void resume() {
    _locationStream?.resume();
  }

  /// Stops tracking the bus.
  void stopTracking() {
    currentLocation = null;
    routeStationInfo = null;
    _locationStream?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    routeCode = null;
    trackingTripId = null;
    trackingFromStation = null;
    stationsOnRoute = null;
    notifyListeners();
  }
}
