import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/components/map/map_preview.dart';
import 'package:via_mallorca/utils/adapt_color.dart';

/// A [MapPreview] of a route: its shape, with a dot per stop.
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({
    super.key,
    required this.points,
    required this.stations,
    required this.color,
    required this.onTap,
  });

  final List<LatLng> points;
  final List<Station> stations;
  final Color color;
  final VoidCallback onTap;

  static const double _stopSize = 9;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor =
        adaptColor(color)[scheme.brightness == Brightness.dark ? 1 : 0];

    return MapPreview(
      onTap: onTap,
      cameraFit: CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(24),
        maxZoom: 16,
      ),
      layers: [
        PolylineLayer(
          polylines: [
            Polyline(points: points, strokeWidth: 3, color: lineColor),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final station in stations)
              Marker(
                width: _stopSize,
                height: _stopSize,
                point: LatLng(station.lat, station.long),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                    border: Border.all(color: lineColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
