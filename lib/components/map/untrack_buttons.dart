import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class UntrackButtons extends StatelessWidget {
  const UntrackButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapProvider>(
        builder: (context, trackingProvider, mapProvider, _) {
      // While tracking, the tracking sheet has the controls
      if (trackingProvider.currentLocation != null) {
        return const SizedBox.shrink();
      }

      // While previewing a route (not tracking): the untrack-route button.
      if (mapProvider.customRoutes != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 82.0, horizontal: 24.0),
          child: ElevatedButton.icon(
              onPressed: mapProvider.clearRoute,
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
                    color: Theme.of(context).colorScheme.onTertiaryContainer),
              )),
        );
      }

      return const SizedBox.shrink();
    });
  }
}
