import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/utils/dark_tile_builder.dart';

/// A small, non-interactive map that opens the full map when tapped.
///
/// Callers supply the camera - either a [cameraFit] or a [center] and [zoom] -
/// and the [layers] drawn over the tiles.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    this.cameraFit,
    this.center,
    this.zoom,
    required this.layers,
    required this.onTap,
  }) : assert(cameraFit != null || center != null,
            'A preview needs either a cameraFit or a center');

  final CameraFit? cameraFit;
  final LatLng? center;
  final double? zoom;
  final List<Widget> layers;
  final VoidCallback onTap;

  static const double height = 170;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MapPreviewFrame(
      child: Stack(
        children: [
          // Gestures never reach the map: the whole preview is one button, and
          // panning it would fight the surrounding scroll view.
          IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
                initialCameraFit: cameraFit,
                initialCenter: center ?? const LatLng(39.607331, 2.983704),
                initialZoom: zoom ?? 16,
              ),
              children: [
                TileLayer(
                  tileBuilder: isDark ? monochromeDarkMode : null,
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'es.opentransportmallorca.via',
                ),
                ...layers,
              ],
            ),
          ),
          const Positioned(top: 8, right: 8, child: _ExpandChip()),
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

/// A preview-shaped placeholder, for while its contents load.
class MapPreviewPlaceholder extends StatelessWidget {
  const MapPreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return MapPreviewFrame(
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

class MapPreviewFrame extends StatelessWidget {
  const MapPreviewFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: MapPreview.height,
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
