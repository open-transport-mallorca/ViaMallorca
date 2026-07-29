import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/components/map/map_preview.dart';
import 'package:via_mallorca/components/map/station_marker.dart';

/// A [MapPreview] centred on a stop, marked with the same pin the main map
/// uses.
class StationMapPreview extends StatelessWidget {
  const StationMapPreview({
    super.key,
    required this.station,
    required this.onTap,
  });

  final Station station;
  final VoidCallback onTap;

  static const double _pinSize = 48;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(station.lat, station.long);

    return MapPreview(
      onTap: onTap,
      center: point,
      zoom: 16,
      layers: [
        MarkerLayer(
          markers: [
            Marker(
              width: _pinSize,
              height: _pinSize,
              alignment: Alignment.topCenter,
              point: point,
              child: StationMarker(
                color: Theme.of(context).colorScheme.primary,
                onColor: Theme.of(context).colorScheme.onPrimary,
                size: _pinSize,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
