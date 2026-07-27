import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:via_mallorca/utils/line_icon.dart';
import 'package:via_mallorca/utils/route_follower.dart';

/// Diameter of the marker's circle, ring included.
const double _markerSize = 52;

/// Width of the ring that separates the marker from the map underneath.
const double _ringWidth = 4;

/// How much saturation the line colour gains before it fills the marker.
///
/// The route is a three pixel line and the marker a solid disc, so the same
/// colour reads considerably heavier here; pushing it lets the vehicle stay
/// the brightest thing on its own route rather than sinking into it.
const double _fillSaturation = 0.25;

/// The tracked bus on the map.
///
/// Fixes arrive roughly every 15 seconds, which at road speed is a couple of
/// hundred metres, so the raw position is animated towards rather than applied
/// outright. Where the drawn route can explain the movement the marker follows
/// it around corners; otherwise it falls back to a straight line, which is what
/// happens when a bus takes a diversion the route does not describe.
class BusTracker extends StatefulWidget {
  const BusTracker({super.key});

  @override
  State<BusTracker> createState() => _BusTrackerState();
}

class _BusTrackerState extends State<BusTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final TrackingProvider _tracking;
  late final MapProvider _map;

  /// The stretch currently being animated along, null before the first fix.
  InterpolatedPath? _path;

  /// The most recent fix, used both as the animation target and to detect
  /// when a new one has arrived.
  LatLng? _lastFix;

  /// Metres along the route at each end of the current animation, null when
  /// that end is not on the drawn route.
  double? _fromDistance;
  double? _toDistance;

  /// Whether a live position has been shown for the current connection.
  ///
  /// Cleared when tracking stops or the socket drops, so the first fix of a
  /// new connection is placed outright rather than animated to.
  bool _hadRealFix = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_onTick);
    _tracking = context.read<TrackingProvider>();
    _map = context.read<MapProvider>();
    _tracking.addListener(_onTrackingChanged);
    // Pick up a trip that was already being tracked before the map mounted.
    // No rebuild request here: the first build has not happened yet.
    _syncFix(notify: false);
  }

  @override
  void dispose() {
    _tracking.removeListener(_onTrackingChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Where the marker is right now, part-way through its animation.
  LatLng? get _displayed {
    final path = _path;
    if (path == null) return _lastFix;
    return path.at(_controller.value);
  }

  void _onTick() {
    _followBus();
    _publishProgress();
  }

  /// Reports how far along the route the bus has reached, so the polylines can
  /// paint what is behind it differently from what is ahead.
  ///
  /// Interpolated between the two fixes rather than re-projecting every frame:
  /// projection is linear in the route's vertex count, and the marker already
  /// moves linearly between the same two points.
  void _publishProgress() {
    final from = _fromDistance;
    final to = _toDistance;

    // The bus left the drawn route; keep the last split rather than flicking
    // the whole route back to one colour.
    if (to == null) return;

    final value = from == null ? to : from + (to - from) * _controller.value;
    final previous = _map.busRouteDistance.value;
    // A metre is a fraction of a pixel at tracking zoom, so skipping smaller
    // changes costs nothing visually and saves repainting the route.
    if (previous != null && (value - previous).abs() < 1) return;
    _map.busRouteDistance.value = value;
  }

  /// Keeps the camera on the bus while follow mode is on.
  ///
  /// Driven by the same animation as the marker and moved outright rather than
  /// animated, so the map glides at the bus's pace instead of chasing it with a
  /// second, competing animation.
  void _followBus() {
    if (!mounted || !_map.followTrackedBus) return;

    final point = _displayed;
    final controller = _map.mapController?.mapController;
    if (point == null || controller == null) return;

    controller.move(point, controller.camera.zoom);
  }

  void _onTrackingChanged() => _syncFix(notify: true);

  void _syncFix({required bool notify}) {
    final fix = _tracking.currentLocation;

    if (fix == null) {
      // Tracking stopped; drop the animation so the next trip starts clean.
      if (_lastFix == null && _path == null) return;
      _controller.stop();
      _path = null;
      _lastFix = null;
      _fromDistance = null;
      _toDistance = null;
      _hadRealFix = false;
      _map.busRouteDistance.value = null;
      if (notify && mounted) setState(() {});
      return;
    }

    if (fix == _lastFix) return;

    final from = _displayed;
    // Until a position message has arrived, what the provider holds is the
    // position tracking started from, not a live one.
    final isPlaceholder = !_tracking.hasBusPosition;
    _lastFix = fix;

    // Put the bus straight where it belongs instead of animating when there is
    // nothing to animate from, when this is the position carried over a
    // reconnect, or when it is the first real fix after one. The bus can have
    // moved a long way while the socket was down, and gliding across that gap
    // over a fix interval reads as the bus slowly driving there.
    if (from == null || isPlaceholder || !_hadRealFix) {
      _hadRealFix = !isPlaceholder;
      _controller.stop();
      _path = null;
      _fromDistance = null;
      _toDistance = _routeProgress()?.distanceAt(fix);
      // The controller will not tick, so publish and recentre by hand.
      _publishProgress();
      if (notify) {
        _followBus();
        if (mounted) setState(() {});
      }
      return;
    }

    final route = _routePoints();
    final points =
        (route == null ? null : pathBetween(route, from, fix)) ?? [from, fix];

    final progress = _routeProgress();
    _fromDistance = progress?.distanceAt(from);
    _toDistance = progress?.distanceAt(fix);

    _path = InterpolatedPath(points);
    _controller.duration = _tracking.fixInterval;
    // Linear: a vehicle covering ground at a steady speed, not a UI element
    // easing into place.
    _controller.forward(from: 0);
    if (notify && mounted) setState(() {});
  }

  /// The tracked route, measured so positions can be placed along it.
  RouteProgress? _routeProgress() {
    final route = _routePoints();
    return route == null ? null : _map.progressFor(route);
  }

  /// The drawn route for the direction being tracked, if one is on the map.
  ///
  /// Only the geometry is wanted here, which is the same in either colour
  /// variant, so the brightness passed is arbitrary.
  List<LatLng>? _routePoints() => _map.basePolyline(Brightness.light)?.points;

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (context, trackingProvider, _) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final point = _displayed;
          return AnimatedMarkerLayer(markers: [
            if (point != null)
              AnimatedMarker(
                  width: 120,
                  height: 120,
                  point: point,
                  builder: (_, animation) => Transform.scale(
                        scale: animation.value,
                        child: _VehicleMarker(tracking: trackingProvider),
                      ))
          ]);
        },
      );
    });
  }
}

/// The vehicle itself: the line's own icon on a filled disc, ringed against the
/// map so it stays legible over both tiles and the drawn route.
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.tracking});

  final TrackingProvider tracking;

  /// The icon the rest of the app already uses for this line, so the marker
  /// matches the departure cards and the tracking sheet.
  IconData get _icon {
    final code = tracking.routeCode;
    if (code != null) return getIconDataFromLineCode(code);
    return switch (tracking.lineType) {
      LineType.train => Icons.train,
      LineType.metro => Icons.subway_outlined,
      _ => Icons.directions_bus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected = tracking.connectionStatus == ConnectionStatus.connected;

    // The line's own colour, in the same variant the route is drawn in, so the
    // vehicle reads as belonging to the route under it. Watched rather than
    // read so a direction switch recolours the marker even between fixes.
    // Falls back to the theme when no route is on the map.
    final line =
        context.watch<MapProvider>().basePolyline(colors.brightness)?.color;
    final accent =
        ColorUtils.saturate(line ?? colors.tertiary, _fillSaturation);

    // Muted while the socket is down: the marker is still where the bus was
    // last seen, and should not read as a live position.
    final fill = connected ? accent : colors.outline;
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return SizedBox.square(
      dimension: _markerSize + _ringWidth * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _markerSize,
            height: _markerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: colors.surface, width: _ringWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(_icon, color: onFill, size: _markerSize / 2),
          ),
          // Sits outside the disc rather than over the icon, so the vehicle
          // stays readable while the connection is being established.
          if (tracking.connectionStatus == ConnectionStatus.connecting)
            SizedBox.square(
              dimension: _markerSize + _ringWidth * 2,
              child: CircularProgressIndicator(
                color: accent,
                strokeWidth: _ringWidth,
              ),
            ),
        ],
      ),
    );
  }
}
