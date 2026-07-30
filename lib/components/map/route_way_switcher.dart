import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class RouteWaySwitcher extends StatelessWidget {
  const RouteWaySwitcher({super.key});

  /// The destination on show, or nothing while the route is still arriving.
  ///
  /// [MapProvider.viewRoute] settles the way before it has fetched the
  /// destinations that back it, and notifies listeners once per subline on the
  /// way through. Between those moments the list is shorter than the index the
  /// way implies, so the way alone cannot be trusted to pick an entry - a loop
  /// has one destination however it is being travelled, and a two-way line has
  /// one until its second subline lands.
  static String _destination(MapProvider mapProvider) {
    final destinations = mapProvider.customRouteDestinations;
    if (destinations == null || destinations.isEmpty) return "";
    final isBack = mapProvider.customWay == Way.back && destinations.length > 1;
    return destinations[isBack ? 1 : 0];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, TrackingProvider>(
        builder: (context, mapProvider, trackingProvider, _) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)),
          child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trackingProvider.routeCode ?? "",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (trackingProvider.currentLocation != null)
                    const SizedBox(width: 10),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: FittedBox(
                        child: Text(_destination(mapProvider)),
                      )),
                  const SizedBox(
                    width: 10,
                  ),
                  if (trackingProvider.currentLocation == null &&
                      (mapProvider.customRouteDestinations ?? []).length > 1)
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: (mapProvider.customWay ?? Way.way) == Way.way
                          ? 0
                          : 0.5,
                      child: IconButton(
                        onPressed: () {
                          mapProvider.setCustomWay(
                              mapProvider.customWay == Way.way
                                  ? Way.back
                                  : Way.way);
                        },
                        icon: const Icon(Icons.compare_arrows_rounded),
                      ),
                    ),
                ],
              )),
        ),
      );
    });
  }
}
