import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/bottom_sheets/timeline/timeline_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class UntrackButtons extends StatelessWidget {
  const UntrackButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapProvider>(
        builder: (context, trackingProvider, mapProvider, _) {
      return Padding(
          padding: EdgeInsets.symmetric(
              vertical: Provider.of<TrackingProvider>(context, listen: false)
                          .currentLocation !=
                      null
                  ? 24.0
                  : 82.0,
              horizontal: 24.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            // Untrack Route Button
            if (mapProvider.customRoutes != null &&
                trackingProvider.currentLocation == null)
              ElevatedButton.icon(
                  onPressed: () {
                    mapProvider.setCustomPolylines(null);
                    mapProvider.setCustomStations([]);
                    mapProvider.setCustomWay(null);
                    mapProvider.setCustomRouteDestinations(null);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.tertiaryContainer),
                  ),
                  icon: Icon(
                    Icons.stop,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.untrackRoute,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer),
                  )),

            // Stop Tracking Bus Button
            if (trackingProvider.currentLocation != null)
              ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<TrackingProvider>().stopTracking();
                    mapProvider.setCustomPolylines(null);
                    mapProvider.setCustomStations([]);
                    mapProvider.setCustomWay(null);
                    mapProvider.setCustomRouteDestinations(null);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.errorContainer),
                  ),
                  icon: Icon(Icons.stop,
                      color: Theme.of(context).colorScheme.error),
                  label: Text(
                    AppLocalizations.of(context)!.stopTracking,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  )),

            // Stop Timeline
            if (trackingProvider.stationsOnRoute != null)
              ElevatedButton.icon(
                label: Text(AppLocalizations.of(context)!.stationsOnRoute),
                icon: const Icon(Icons.timeline),
                onPressed: () {
                  showBottomSheet(
                      context: context,
                      builder: (context) => const TimelineSheet());
                },
              )
          ]));
    });
  }
}
