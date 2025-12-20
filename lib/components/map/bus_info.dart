import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class BusInfo extends StatelessWidget {
  const BusInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapProvider>(
        builder: (context, trackingProvider, mapProvider, _) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: trackingProvider.currentLocation == null ? 0 : 1,
        child: Align(
            alignment: Alignment.topRight,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: 250,
                  height: 150,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(builder: (context) {
                      final routeCode = trackingProvider.routeCode;
                      final destinations = mapProvider.customRouteDestinations;
                      final way = mapProvider.customWay;
                      final stationInfo = trackingProvider.routeStationInfo;
                      final speed = trackingProvider.currentSpeed;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Skeletonizer(
                            enabled: routeCode == null || destinations == null,
                            child: Text(
                              "${routeCode ?? ''} - ${destinations != null ? destinations[way == Way.way ? 0 : 1] : ''}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: Text(
                              "${AppLocalizations.of(context)!.passengers}: ${stationInfo?.passangers.inBus ?? '-'} / ${stationInfo?.passangers.totalCapacity ?? '-'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (stationInfo != null &&
                                        stationInfo.passangers.inBus <
                                            stationInfo
                                                .passangers.totalCapacity)
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          Skeletonizer(
                            enabled: speed == null,
                            child: Text(
                                "${AppLocalizations.of(context)!.speed}: ${speed ?? '-'} km/h"),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: FittedBox(
                              child: Text(
                                "${AppLocalizations.of(context)!.nextStop}: ${stationInfo?.stops.first.stopName ?? ''}",
                              ),
                            ),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: FittedBox(
                              child: Text(
                                "${AppLocalizations.of(context)!.finalStop}: ${stationInfo?.stops.last.stopName ?? ''}",
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ))),
      );
    });
  }
}
