import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/extensions/grayscale_filter.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class BusTracker extends StatelessWidget {
  const BusTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (context, trackingProvider, _) {
      return AnimatedMarkerLayer(markers: [
        if (trackingProvider.currentLocation != null)
          AnimatedMarker(
              width: 120,
              height: 120,
              point: LatLng(trackingProvider.currentLocation!.latitude,
                  trackingProvider.currentLocation!.longitude),
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
                            colorFilter: trackingProvider.connectionStatus !=
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
                                color: Theme.of(context).colorScheme.primary,
                                strokeWidth: 3,
                              ),
                            ),
                        ],
                      ),
                    ));
              })
      ]);
    });
  }
}
