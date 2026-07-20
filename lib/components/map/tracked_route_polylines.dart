import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';

/// The highlighted route, split at the tracked bus into the stretch already
/// covered and the stretch still ahead.
///
/// Falls back to the plain single polyline whenever there is no tracked bus, or
/// the bus is somewhere the route does not go.
class TrackedRoutePolylines extends StatelessWidget {
  const TrackedRoutePolylines({super.key});

  /// Dash length and gap, in pixels, for the stretch still to come.
  static const List<double> _dashes = [6, 6];

  /// How much of the line colour is left on the stretch still to come.
  ///
  /// Only a slight step back from the covered stretch: the dashes already
  /// distinguish the two, so this is a hint rather than a fade.
  static const double _remainingOpacity = 0.75;

  @override
  Widget build(BuildContext context) {
    // Watched, not read: this subscribes the widget itself, so a direction
    // switch or a newly loaded route repaints it even though the parent hands
    // down a canonicalised const instance that would otherwise skip rebuild.
    final mapProvider = context.watch<MapProvider>();
    final base = _basePolyline(context, mapProvider);
    if (base == null) return const SizedBox.shrink();

    // The dashes cover the whole route rather than only the part still to come,
    // so their geometry never changes and they stay put on the ground. Dashing
    // just the remaining stretch would slide the pattern along as the bus moves
    // - its start point is the cut, and the default PatternFit rescales every
    // dash to fit a line that is continuously getting shorter.
    final dashed = Polyline(
      points: base.points,
      strokeWidth: base.strokeWidth,
      color: base.color.withValues(alpha: _remainingOpacity),
      pattern: StrokePattern.dashed(segments: _dashes),
    );

    return ValueListenableBuilder<double?>(
      valueListenable: mapProvider.busRouteDistance,
      builder: (context, distance, _) {
        if (distance == null) return PolylineLayer(polylines: [base]);

        // Ground already covered goes over the dashes, hiding them: solid for
        // what has happened, dashes left showing for what is still to come.
        final travelled =
            mapProvider.progressFor(base.points).split(distance).travelled;
        return PolylineLayer(polylines: [
          dashed,
          if (travelled.length > 1)
            Polyline(
              points: travelled,
              strokeWidth: base.strokeWidth,
              color: base.color,
            ),
        ]);
      },
    );
  }

  /// The route as drawn today: one of two colour variants, and for a line with
  /// separate directions the one matching the way on show.
  Polyline? _basePolyline(BuildContext context, MapProvider mapProvider) {
    final routes = mapProvider.customRoutes;
    if (routes == null || routes.length < 2) return null;

    final polylines = routes[
        Theme.of(context).colorScheme.brightness == Brightness.light ? 0 : 1];
    if (polylines.isEmpty) return null;
    if (polylines.length == 1) return polylines.first;

    final way = mapProvider.customWay;
    return polylines[way == null || way == Way.way ? 0 : 1];
  }
}
