import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/tracking_notification.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/eta_format.dart';

typedef _RouteMeasure = ({
  double bus,
  ({double distance, String name})? boarding,
  double end,
});

enum TripPhase {
  /// The bus is on its way to the stop the user is tracking from
  approaching,

  /// The bus has passed it, so the user is presumably aboard
  riding,
}

class TripSummary {
  const TripSummary({
    required this.phase,
    required this.target,
    this.nextStop,
    this.finalStop,
    this.arrival,
    this.minutes,
    this.stopsLeft,
    this.metersLeft,
    this.progress,
    this.progressSpan,
  });

  final TripPhase phase;

  /// The boarding stop while approaching, the end of the route while riding
  final String target;
  final String? nextStop;
  final String? finalStop;

  /// Arrival at [target]; null with [minutes] until the socket sends the stops
  final DateTime? arrival;
  final int? minutes;

  /// Stops before [target] while approaching, stops left while riding
  final int? stopsLeft;

  /// Along the drawn route, null when the bus can't be placed on it
  final double? metersLeft;
  final double? progress;

  /// Metres along the drawn route that [progress] runs between, when it is
  /// distance based, so the sheet can follow the bus marker frame by frame
  final ({double from, double to})? progressSpan;
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class TrackingProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// [onStoppedFromNotification] does what the in-app stop button does
  /// beyond [stopTracking], and [trackedRoute] reads the route drawn on the
  /// map; this provider can't reach either
  TrackingProvider({
    VoidCallback? onStoppedFromNotification,
    TrackedRoute? Function(int? stationId)? trackedRoute,
  }) : _trackedRoute = trackedRoute {
    TrackingNotificationApi.setHandlers(
      onStopRequested: () async {
        await stopTracking();
        onStoppedFromNotification?.call();
      },
      onDismissed: () => _notificationActive = false,
    );
  }

  final TrackedRoute? Function(int? stationId)? _trackedRoute;

  DateTime? _expectedArrival;
  String? _boardingStopName;

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

  /// The last stop the bus pulled into.
  ///
  /// Sent by the socket each time the bus reaches a stop, carrying how late it
  /// was and how many people were aboard — the only place the app learns the
  /// size of a delay rather than just that there is one.
  BusStopped? lastStop;

  /// How far behind schedule the bus was at [lastStop], in minutes.
  ///
  /// Null until it reaches its first stop. Negative means it was early.
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

  /// When the vehicle recorded its last position, by its own clock.
  ///
  /// Only differences between these are meaningful — the clock is the bus's,
  /// not the phone's — but that is enough to tell a stale position from a
  /// fresh one.
  DateTime? lastFixRecordedAt;

  /// [recordedAt] is the vehicle's own timestamp for the fix. Measuring the
  /// gap between those rather than between arrivals here keeps network jitter
  /// out of the animation duration; it falls back to local time when the
  /// message carries no timestamp.
  void _recordFixTiming(DateTime? recordedAt) {
    final now = recordedAt ?? DateTime.now();
    final previous = recordedAt == null ? lastFixAt : lastFixRecordedAt;
    lastFixAt = DateTime.now();
    if (recordedAt != null) lastFixRecordedAt = recordedAt;
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

  /// The bus reached the end of its route, nothing left to reconnect to
  bool _tripFinished = false;

  /// Lets callbacks from a replaced socket be ignored
  int _connectionGeneration = 0;

  DateTime? _lastMessageAt;

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  Timer? _watchdog;

  /// A socket this quiet is dead even if it never closed (network switch, NAT
  /// timeout)
  static const Duration _silenceLimit = Duration(seconds: 60);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  ConnectionStatus get connectionStatus => _connectionStatus;

  void _setConnectionStatus(ConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      notifyListeners();
      _publishNotification();
    }
  }

  bool _notificationActive = false;
  TrackingNotificationContent? _lastNotification;

  /// The notification's progress eases from one fix's value to the next over
  /// a fix interval, re-posted every couple of seconds, instead of jumping
  double? _progressFrom;
  double? _progressTo;
  DateTime? _progressSince;
  Timer? _progressTicker;

  /// Where and when the wait for the bus / the ride began, for the progress bar
  double? _approachStartDistance;
  double? _rideStartDistance;
  DateTime? _approachStartedAt;
  DateTime? _rideStartedAt;

  /// [expectedArrival] and [boardingStopName] come from the departure tracked
  /// from, and stand in until the socket sends the stops
  Future<void> startTracking(
    int tripId,
    String lineCode,
    LatLng initialCoords,
    int trackingFrom, {
    DateTime? expectedArrival,
    String? boardingStopName,
  }) async {
    await stopTracking();
    WidgetsBinding.instance.addObserver(this);
    _isTracking = true;
    await refreshWakelock();

    // Restore the last known position before announcing the new status: the
    // status change is what notifies listeners, and until they have a position
    // again the bus vanishes from the map.
    trackingTripId = tripId;
    trackingFromStation = trackingFrom;
    currentLocation = initialCoords;
    _expectedArrival = expectedArrival;
    _boardingStopName = boardingStopName;

    _connect();
    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) => _checkIn());
    // Android only: iOS budgets Live Activity updates far too tightly for this
    if (Platform.isAndroid) {
      _progressTicker = Timer.periodic(
          const Duration(seconds: 2), (_) => _publishNotification());
    }

    // Before any await: the foreground service must start from the foreground
    _notificationActive = true;
    final l10n = _localizations();
    final content = _notificationContent(l10n, fallbackLine: lineCode);
    _lastNotification = content;
    TrackingNotificationApi.start(
      content,
      stopLabel: l10n.stopTracking,
      channelName: l10n.trackingChannelName,
      channelDescription: l10n.trackingChannelDescription,
    );

    final routeLine = await RouteLinesApi.getLine(lineCode);
    if (trackingTripId != tripId) return;
    lineType = routeLine.type;
    routeCode = routeLine.code;
    notifyListeners();
    _publishNotification();
  }

  void _connect() {
    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    _locationStream?.cancel();
    _channel?.sink.close();

    // Gives the handshake time before the watchdog kicks in
    _lastMessageAt = DateTime.now();
    _setConnectionStatus(ConnectionStatus.connecting);

    final channel = LocationWebSocket.locationChannel(trackingTripId!);
    _channel = channel;
    // A failed handshake also surfaces on the stream
    channel.ready.ignore();

    _locationStream = channel.stream.listen(
      (message) {
        if (generation != _connectionGeneration) return;
        _handleMessage(message);
      },
      onDone: () {
        if (generation != _connectionGeneration) return;
        debugPrint("WebSocket connection closed");
        _onConnectionLost();
      },
      onError: (e) {
        if (generation != _connectionGeneration) return;
        debugPrint("WebSocket error: $e");
        _onConnectionLost();
      },
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic message) {
    _lastMessageAt = DateTime.now();
    _reconnectAttempt = 0;

    final Object action;
    try {
      final json = jsonDecode(message) as Map;
      final type = json['type'];
      if (type == 'position') {
        hasBusPosition = true;
      } else if (type == 'esta-info') {
        hasStationInfo = true;
      }
      action = LocationWebSocket.locationParser(json);
    } catch (e) {
      debugPrint("Unreadable tracking message: $e");
      return;
    }

    if (_connectionStatus != ConnectionStatus.connected) {
      _setConnectionStatus(ConnectionStatus.connected);
    }

    if (action is BusPosition) {
      currentLocation = LatLng(action.lat, action.long);
      currentSpeed = action.speed?.round();
      _recordFixTiming(action.recordedAt);
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
        _recordFixTiming(embedded.recordedAt);
      }
    } else if (action is ConnectionClose) {
      _finishTrip();
    }

    notifyListeners();
    _publishNotification();
  }

  /// Retries with backoff, in the background too
  void _onConnectionLost() {
    _locationStream = null;
    _setConnectionStatus(ConnectionStatus.disconnected);
    if (!_isTracking || _tripFinished) return;

    final delay = Duration(
      seconds:
          min(_maxReconnectDelay.inSeconds, 1 << min(_reconnectAttempt, 5)),
    );
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  /// Reopens a silent socket and keeps the notification's minutes counting
  void _checkIn() {
    if (!_isTracking || _tripFinished) return;
    final last = _lastMessageAt;
    if (_connectionStatus != ConnectionStatus.disconnected &&
        last != null &&
        DateTime.now().difference(last) > _silenceLimit) {
      debugPrint("WebSocket silent for over $_silenceLimit. Reconnecting...");
      _connect();
    }
    _publishNotification();
  }

  /// The map keeps its last state until the user stops tracking
  void _finishTrip() {
    _tripFinished = true;
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    _progressTicker?.cancel();
    if (!_notificationActive) return;
    _notificationActive = false;

    final l10n = _localizations();
    final finalStop = stationsOnRoute?.lastOrNull?.stopName;
    TrackingNotificationApi.stop(
      finalContent: TrackingNotificationContent(
        title: l10n.tripFinished,
        body: finalStop,
        subtitle: routeCode,
        progress: 1,
      ),
    );
  }

  /// Holds the screen awake for as long as a bus is being followed, if the user
  /// asked for that.
  ///
  /// Watching a bus approach is the one thing this app is used for with the
  /// screen on and untouched, which is exactly when the display times out.
  /// Called again when the preference changes so it takes effect mid-trip.
  Future<void> refreshWakelock() async {
    final shouldHold =
        _isTracking && LocalStorageApi.keepScreenOnWhileTracking();
    if (await WakelockPlus.enabled == shouldHold) return;
    await WakelockPlus.toggle(enable: shouldHold);
  }

  Future<void> stopTracking() async {
    WidgetsBinding.instance.removeObserver(this);
    final wasTracking = _isTracking;
    _isTracking = false;
    await refreshWakelock();

    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    _progressTicker?.cancel();
    _progressTicker = null;
    _progressFrom = null;
    _progressTo = null;
    _progressSince = null;
    _reconnectAttempt = 0;
    _lastMessageAt = null;
    _tripFinished = false;

    _notificationActive = false;
    _lastNotification = null;
    _approachStartDistance = null;
    _rideStartDistance = null;
    _approachStartedAt = null;
    _rideStartedAt = null;
    if (wasTracking) await TrackingNotificationApi.stop();

    await _locationStream?.cancel();
    _locationStream = null;

    await _channel?.sink.close();
    _channel = null;

    trackingTripId = null;
    trackingFromStation = null;
    _expectedArrival = null;
    _boardingStopName = null;
    currentLocation = null;
    stationsOnRoute = null;
    routeStationInfo = null;
    currentSpeed = null;
    hasBusPosition = false;
    hasStationInfo = false;
    lastStop = null;
    lastFixAt = null;
    lastFixRecordedAt = null;
    fixInterval = const Duration(seconds: 15);

    _setConnectionStatus(ConnectionStatus.disconnected);
    notifyListeners();
  }

  void _publishNotification() {
    if (!_notificationActive) return;
    var content = _notificationContent(_localizations());
    final progress = _easedProgress(content.progress);
    if (progress != content.progress) {
      content = TrackingNotificationContent(
        title: content.title,
        body: content.body,
        subtitle: content.subtitle,
        chip: content.chip,
        progress: progress,
      );
    }
    if (content == _lastNotification) return;
    _lastNotification = content;
    TrackingNotificationApi.update(content);
  }

  /// [target] reached gradually; rounded to the 1% a notification can show,
  /// so a settled bar doesn't re-post
  double? _easedProgress(double? target) {
    if (target == null || !Platform.isAndroid) {
      _progressFrom = _progressTo = target;
      return target;
    }

    final now = DateTime.now();
    if (target != _progressTo) {
      final current = _progressAt(now) ?? target;
      // A new phase starts the bar over; easing back down would look wrong
      _progressFrom = target < current - 0.2 ? target : current;
      _progressTo = target;
      _progressSince = now;
    }
    return ((_progressAt(now) ?? target) * 100).round() / 100;
  }

  double? _progressAt(DateTime now) {
    final from = _progressFrom;
    final to = _progressTo;
    final since = _progressSince;
    if (from == null || to == null || since == null) return to;
    final t = now.difference(since).inMilliseconds / fixInterval.inMilliseconds;
    return from + (to - from) * t.clamp(0.0, 1.0);
  }

  /// Where the trip stands, shared by the tracking sheet and the notification
  ///
  /// About the boarding stop until the bus passes it, then (user presumably
  /// aboard) about the end of the route. Null until there is anything to say.
  /// Not a pure getter: the first call of each phase fixes where its progress
  /// is measured from.
  TripSummary? tripSummary() {
    final stops = stationsOnRoute;
    final measured = _measureRoute();

    // The socket can take a while to send the stops; until then the departure
    // tracked from and the drawn route still say when and how far
    if (stops == null || stops.isEmpty) {
      final boarding = measured?.boarding;
      final metersLeft = measured == null || boarding == null
          ? null
          : boarding.distance - measured.bus;
      final target = boarding?.name ?? _boardingStopName;
      final expected = _expectedArrival;
      if (target == null ||
          (metersLeft != null && metersLeft <= 0) ||
          (metersLeft == null && expected == null)) {
        return null;
      }
      return TripSummary(
        phase: TripPhase.approaching,
        target: target,
        arrival: expected,
        minutes: expected == null ? null : _minutesTo(expected),
        metersLeft: metersLeft,
        progress: _approachProgress(measured, expected),
        progressSpan: _approachSpan(measured),
      );
    }

    final finalStop = stops.last;
    final boardingIndex =
        stops.indexWhere((stop) => stop.stopId == trackingFromStation);
    if (boardingIndex >= 0) {
      final boarding = stops[boardingIndex];
      final boardingDistance = measured?.boarding?.distance;
      final arrival = _arrivalOf(boarding);
      return TripSummary(
        phase: TripPhase.approaching,
        target: boarding.stopName,
        nextStop: stops.first.stopName,
        finalStop: finalStop.stopName,
        arrival: arrival,
        minutes: _minutesUntil(boarding),
        stopsLeft: boardingIndex,
        metersLeft: measured == null || boardingDistance == null
            ? null
            : max(0, boardingDistance - measured.bus),
        progress: _approachProgress(measured, arrival),
        progressSpan: _approachSpan(measured),
      );
    }

    final arrival = _arrivalOf(finalStop);
    return TripSummary(
      phase: TripPhase.riding,
      target: finalStop.stopName,
      nextStop: stops.first.stopName,
      finalStop: finalStop.stopName,
      arrival: arrival,
      minutes: _minutesUntil(finalStop),
      stopsLeft: stops.length,
      metersLeft: measured == null ? null : max(0, measured.end - measured.bus),
      progress: _rideProgress(measured, arrival),
      progressSpan: _rideSpan(measured),
    );
  }

  TrackingNotificationContent _notificationContent(
    AppLocalizations l10n, {
    String? fallbackLine,
  }) {
    final line = routeCode ?? fallbackLine ?? '';
    final reconnecting = _connectionStatus == ConnectionStatus.disconnected;
    final delay = delayMinutes;
    final notes = [
      if (delay != null && delay > 0) l10n.minutesLate(delay),
      if (reconnecting) l10n.trackingReconnecting,
    ];

    final trip = tripSummary();
    if (trip == null) {
      return TrackingNotificationContent(
        title: line,
        body: hasBusPosition
            ? (notes.isEmpty ? null : notes.join(' · '))
            : reconnecting
                ? l10n.trackingReconnecting
                : l10n.trackingConnecting,
      );
    }

    final minutes = trip.minutes;
    final arrival = trip.arrival;
    if (minutes == null || arrival == null) {
      final distance = _formatDistance(trip.metersLeft ?? 0);
      return TrackingNotificationContent(
        title: l10n.trackingArrivingAt(trip.target),
        body: [l10n.trackingDistanceAway(distance), ...notes].join(' · '),
        subtitle: line,
        chip: distance,
        progress: trip.progress,
      );
    }

    if (trip.phase == TripPhase.approaching) {
      return TrackingNotificationContent(
        title: l10n.trackingArrivingAt(trip.target),
        body: [
          l10n.arrivingIn(minutes),
          if (trip.stopsLeft != null) l10n.stopsAway(trip.stopsLeft!),
          ...notes
        ].join(' · '),
        subtitle: trip.finalStop == null
            ? line
            : l10n.lineTowards(line, trip.finalStop!),
        chip: minutes == 0 ? l10n.arrivingIn(0) : formatEtaShort(minutes, l10n),
        progress: trip.progress,
      );
    }

    return TrackingNotificationContent(
      title: l10n.trackingNextStop(trip.nextStop ?? trip.target),
      body: [
        l10n.trackingFinalStopAt(trip.target, DateFormat.Hm().format(arrival)),
        ...notes,
      ].join(' · '),
      subtitle: line,
      chip: formatEtaShort(minutes, l10n),
      progress: trip.progress,
    );
  }

  /// Metres along the drawn route of the bus, the boarding stop and the end,
  /// or null when the bus can't be placed on it
  _RouteMeasure? _measureRoute() {
    final location = currentLocation;
    final tracked = _trackedRoute?.call(trackingFromStation);
    if (!hasBusPosition || location == null || tracked == null) return null;

    final route = tracked.route;
    final bus = route.distanceAt(location);
    if (bus == null) return null;

    final station = tracked.station;
    final boarding = station == null
        ? null
        : route.distanceAt(LatLng(station.lat, station.long));
    return (
      bus: bus,
      boarding:
          boarding == null ? null : (distance: boarding, name: station!.name),
      end: route.length,
    );
  }

  /// By distance along the route, by time when that isn't measurable
  double? _approachProgress(_RouteMeasure? measured, DateTime? arrival) {
    final startedAt = _approachStartedAt ??= DateTime.now();
    final boarding = measured?.boarding;
    if (measured != null && boarding != null) {
      final start = _approachStartDistance ??= measured.bus;
      final progress =
          _distanceProgress(start, measured.bus, boarding.distance);
      if (progress != null) return progress;
    }
    return arrival == null ? null : _timeProgress(startedAt, arrival);
  }

  double _rideProgress(_RouteMeasure? measured, DateTime arrival) {
    final startedAt = _rideStartedAt ??= DateTime.now();
    if (measured != null) {
      final start = _rideStartDistance ??= measured.bus;
      final progress = _distanceProgress(start, measured.bus, measured.end);
      if (progress != null) return progress;
    }
    return _timeProgress(startedAt, arrival);
  }

  ({double from, double to})? _approachSpan(_RouteMeasure? measured) {
    final boarding = measured?.boarding;
    if (measured == null || boarding == null) return null;
    final start = _approachStartDistance ??= measured.bus;
    if (boarding.distance <= start) return null;
    return (from: start, to: boarding.distance);
  }

  ({double from, double to})? _rideSpan(_RouteMeasure? measured) {
    if (measured == null) return null;
    final start = _rideStartDistance ??= measured.bus;
    if (measured.end <= start) return null;
    return (from: start, to: measured.end);
  }

  double? _distanceProgress(double start, double bus, double target) {
    final span = target - start;
    if (span <= 0) return null;
    return ((bus - start) / span).clamp(0.0, 1.0);
  }

  double _timeProgress(DateTime start, DateTime arrival) {
    final now = DateTime.now();
    final elapsed = now.difference(start).inSeconds;
    final remaining = max(0, arrival.difference(now).inSeconds);
    if (elapsed + remaining == 0) return 0;
    return elapsed / (elapsed + remaining);
  }

  /// Live estimate, falling back to the timetable
  DateTime _arrivalOf(StationOnRoute stop) {
    final estimate = stop.estimatedArrival;
    if (estimate != null) return estimate;
    // Scheduled times carry only a time of day
    final now = DateTime.now();
    final scheduled = stop.scheduledArrival;
    return DateTime(
        now.year, now.month, now.day, scheduled.hour, scheduled.minute);
  }

  int _minutesUntil(StationOnRoute stop) => _minutesTo(_arrivalOf(stop));

  int _minutesTo(DateTime arrival) {
    final seconds = arrival.difference(DateTime.now()).inSeconds;
    return max(0, (seconds / 60).ceil());
  }

  /// No BuildContext here, so resolve the locale like MaterialApp does
  Locale _locale() =>
      LocaleProvider().locale ??
      basicLocaleListResolution(
        WidgetsBinding.instance.platformDispatcher.locales,
        AppLocalizations.supportedLocales,
      );

  AppLocalizations _localizations() => lookupAppLocalizations(_locale());

  String _formatDistance(double meters) =>
      DistanceFormatter.formatDistanceIn(meters, _locale());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_isTracking || _tripFinished) {
      return;
    }

    // iOS suspends the socket, and on Android the service may have been
    // dismissed, so don't wait out the backoff or the watchdog
    final last = _lastMessageAt;
    final stale =
        last == null || DateTime.now().difference(last) > fixInterval * 2;
    if (_connectionStatus == ConnectionStatus.disconnected || stale) {
      debugPrint("App resumed and was tracking. Reconnecting...");
      _reconnectAttempt = 0;
      _connect();
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
