import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/screens/map/map_viewmodel.dart';

class UpdateLocationButtons extends StatelessWidget {
  const UpdateLocationButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapViewModel>(
        builder: (context, trackingProvider, viewModel, _) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (trackingProvider.currentLocation != null)
              // Move to Bus
              FloatingActionButton(
                  heroTag: 'moveToBus',
                  mini: true,
                  onPressed: () {
                    // Recentring on the bus also resumes following it.
                    context.read<MapProvider>().setFollowTrackedBus(true);
                    viewModel.moveToLocation(
                        context: context,
                        position: trackingProvider.currentLocation!,
                        zoom: MapProvider.trackingZoom);
                  },
                  child: const Icon(Icons.directions_bus)),

            // Move to Current Location
            FloatingActionButton(
                heroTag: 'moveToCurrentLocation',
                onPressed: () async => viewModel.moveToCurrentLocation(context),
                child: Icon((viewModel.locationPermission ==
                            LocationPermission.whileInUse ||
                        viewModel.locationPermission ==
                            LocationPermission.always)
                    ? Icons.my_location
                    : Icons.location_searching)),
          ],
        ),
      );
    });
  }
}
