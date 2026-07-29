import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:via_mallorca/utils/dark_tile_builder.dart';

/// A small, non-interactive map showing the shape of a route, which opens the
/// full map when tapped.
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
  static const double height = 170;
  static const double _stopSize = 9;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final lineColor = adaptColor(color)[isDark ? 1 : 0];

    return _PreviewFrame(
      child: Stack(
        children: [
          IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(24),
                  maxZoom: 16,
                ),
              ),
              children: [
                TileLayer(
                  tileBuilder: isDark ? monochromeDarkMode : null,
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'es.opentransportmallorca.via',
                ),
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
            ),
          ),
          const Positioned(
            top: 8,
            right: 8,
            child: _ExpandChip(),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Semantics(
                button: true,
                label: AppLocalizations.of(context)!.viewOnMap,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteMapPreviewPlaceholder extends StatelessWidget {
  const RouteMapPreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: RouteMapPreview.height,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

class _ExpandChip extends StatelessWidget {
  const _ExpandChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.open_in_full, size: 16, color: scheme.onSurface),
    );
  }
}
