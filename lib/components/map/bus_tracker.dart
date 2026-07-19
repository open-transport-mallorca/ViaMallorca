import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/extensions/grayscale_filter.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/route_follower.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_followBus);
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
      if (notify && mounted) setState(() {});
      return;
    }

    if (fix == _lastFix) return;

    final from = _displayed;
    _lastFix = fix;

    // Nothing on screen yet, so there is nothing to animate from.
    if (from == null) {
      _path = null;
      if (notify && mounted) setState(() {});
      return;
    }

    final route = _routePoints();
    final points =
        (route == null ? null : pathBetween(route, from, fix)) ?? [from, fix];

    _path = InterpolatedPath(points);
    _controller.duration = _tracking.fixInterval;
    // Linear: a vehicle covering ground at a steady speed, not a UI element
    // easing into place.
    _controller.forward(from: 0);
    if (notify && mounted) setState(() {});
  }

  /// The drawn route for the direction being tracked, if one is on the map.
  ///
  /// [MapProvider.customRoutes] holds a light and a dark coloured copy of the
  /// same geometry, one polyline per subline, so either colour serves and the
  /// index follows the same way convention the map itself uses.
  List<LatLng>? _routePoints() {
    final routes = _map.customRoutes;
    if (routes == null || routes.isEmpty) return null;
    final polylines = routes.first;
    if (polylines.isEmpty) return null;
    if (polylines.length == 1) return polylines.first.points;
    return polylines[_map.customWay == Way.back ? 1 : 0].points;
  }

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
                  builder: (_, animation) {
                    return Container(
                        width: 60 * animation.value,
                        height: 60 * animation.value,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.9)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ColorFiltered(
                                colorFilter:
                                    trackingProvider.connectionStatus !=
                                            ConnectionStatus.connected
                                        ? ColorFilterX.grayscale()
                                        : const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.dst,
                                          ),
                                child: Image.asset(
                                  trackingProvider.lineType == LineType.bus ||
                                          trackingProvider.lineType ==
                                              LineType.unknown ||
                                          trackingProvider.lineType == null
                                      ? "assets/bus.png"
                                      : "assets/train.png",
                                  height: 50 * animation.value,
                                ),
                              ),
                              if (trackingProvider.connectionStatus ==
                                  ConnectionStatus.connecting)
                                SizedBox(
                                  width: 40 * animation.value,
                                  height: 40 * animation.value,
                                  child: CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    strokeWidth: 3,
                                  ),
                                ),
                            ],
                          ),
                        ));
                  })
          ]);
        },
      );
    });
  }
}
