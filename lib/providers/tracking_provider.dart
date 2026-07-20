import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class TrackingProvider extends ChangeNotifier with WidgetsBindingObserver {
  LatLng? currentLocation;
  RouteStationInfo? routeStationInfo;
  int? currentSpeed;
  int? trackingTripId;
  LineType? lineType;
  String? routeCode;
  List<StationOnRoute>? stationsOnRoute;
  int? trackingFromStation;
  bool hasBusPosition = false;
  bool hasStationInfo = false;

  /// The last stop the bus called at.
  ///
  /// Sent by the socket each time the bus reaches a stop, carrying how late it
  /// was and how many people were aboard — the only place the app learns the
  /// size of a delay rather than just that there is one.
  BusStopped? lastStop;

  /// How far behind schedule the bus was at [lastStop], in minutes.
  ///
  /// Null until it calls somewhere. Negative means it was running early.
  int? get delayMinutes => lastStop?.delay;

  /// When the last position fix arrived.
  DateTime? lastFixAt;

  /// Rolling estimate of the gap between position fixes.
  ///
  /// The tracking socket emits a position roughly every 15 seconds; the marker
  /// animation spans this so the bus keeps moving between fixes instead of
  /// jumping. Smoothed rather than taken raw so one late packet does not stall
  /// the marker.
  Duration fixInterval = const Duration(seconds: 15);

  static const Duration _minFixInterval = Duration(seconds: 4);
  static const Duration _maxFixInterval = Duration(seconds: 25);

  void _recordFixTiming() {
    final now = DateTime.now();
    final previous = lastFixAt;
    lastFixAt = now;
    if (previous == null) return;

    final observed = now.difference(previous);
    if (observed < _minFixInterval || observed > _maxFixInterval) return;
    fixInterval = Duration(
      milliseconds:
          (fixInterval.inMilliseconds * 0.7 + observed.inMilliseconds * 0.3)
              .round(),
    );
  }

  WebSocketChannel? _channel;
  StreamSubscription? _locationStream;

  bool _isTracking = false;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  ConnectionStatus get connectionStatus => _connectionStatus;

  AppLifecycleState? _appLifecycleState = AppLifecycleState.resumed;

  void _setConnectionStatus(ConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      notifyListeners();
    }
  }

  Future<void> startTracking(
    int tripId,
    String lineCode,
    LatLng initialCoords,
    int trackingFrom,
  ) async {
    await stopTracking();
    WidgetsBinding.instance.addObserver(this);
    _isTracking = true;

    // Restore the last known position before announcing the new status: the
    // status change is what notifies listeners, and until they have a position
    // again the bus vanishes from the map. Reconnecting after a spell in the
    // background waits on a route fetch and a socket handshake, so that gap is
    // long enough to see.
    trackingTripId = tripId;
    trackingFromStation = trackingFrom;
    currentLocation = initialCoords;

    _setConnectionStatus(ConnectionStatus.connecting);

    final routeLine = await RouteLinesApi.getLine(lineCode);
    lineType = routeLine.type;
    routeCode = routeLine.code;

    _channel = LocationWebSocket.locationChannel(tripId);

    _locationStream = _channel!.stream.listen(
      (location) {
        final json = jsonDecode(location) as Map;
        final type = json['type'];

        if (type == 'position') {
          hasBusPosition = true;
        } else if (type == 'esta-info') {
          hasStationInfo = true;
        }

        if (_connectionStatus != ConnectionStatus.connected) {
          _setConnectionStatus(ConnectionStatus.connected);
        }

        final action = LocationWebSocket.locationParser(json);

        if (action is BusPosition) {
          currentLocation = LatLng(action.lat, action.long);
          currentSpeed = action.speed?.round();
          _recordFixTiming();
        } else if (action is BusStopped) {
          lastStop = action;
        } else if (action is RouteStationInfo) {
          routeStationInfo = action;
          stationsOnRoute = action.stops;

          // Every stop-info message carries a position of its own, so taking it
          // gives a denser stream than the position messages alone. Duplicates
          // cost nothing: an unchanged location is ignored downstream, and
          // _recordFixTiming discards gaps too short to be a real interval.
          final embedded = action.position;
          if (embedded != null) {
            currentLocation = LatLng(embedded.lat, embedded.long);
            currentSpeed = embedded.speed?.round();
            hasBusPosition = true;
            _recordFixTiming();
          }
        }

        notifyListeners();
      },
      onDone: () {
        _setConnectionStatus(ConnectionStatus.disconnected);
        debugPrint("WebSocket connection closed");

        if (_appLifecycleState == AppLifecycleState.resumed &&
            _isTracking &&
            _connectionStatus == ConnectionStatus.disconnected) {
          debugPrint("App resumed and was tracking. Reconnecting...");
          startTracking(
            trackingTripId!,
            routeCode!,
            currentLocation!,
            trackingFromStation!,
          );
        }
      },
      onError: (e) {
        _setConnectionStatus(ConnectionStatus.disconnected);
        debugPrint("WebSocket error: $e");
      },
    );
  }

  Future<void> stopTracking() async {
    WidgetsBinding.instance.removeObserver(this);
    _isTracking = false;

    await _locationStream?.cancel();
    _locationStream = null;

    await _channel?.sink.close();
    _channel = null;

    trackingTripId = null;
    trackingFromStation = null;
    currentLocation = null;
    stationsOnRoute = null;
    routeStationInfo = null;
    currentSpeed = null;
    hasBusPosition = false;
    hasStationInfo = false;
    lastStop = null;
    lastFixAt = null;
    fixInterval = const Duration(seconds: 15);

    _setConnectionStatus(ConnectionStatus.disconnected);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    final isNowForeground = state == AppLifecycleState.resumed;

    if (isNowForeground &&
        _isTracking &&
        _connectionStatus == ConnectionStatus.disconnected) {
      debugPrint("App resumed and was tracking. Reconnecting...");
      startTracking(
        trackingTripId!,
        routeCode!,
        currentLocation!,
        trackingFromStation!,
      );
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
