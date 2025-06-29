import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/components/popups/location_denied_popup.dart';
import 'package:via_mallorca/components/skeletons/nearby_card_skeleton.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/nearby/nearby_viewmodel.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/station_sort.dart';

class NearbyStops extends StatelessWidget {
  const NearbyStops({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NearbyStopsViewModel()..initialize(),
      child: Consumer<NearbyStopsViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.errorMessage != null) {
            return Center(
              child: Text(
                '${AppLocalizations.of(context)!.error}: ${viewModel.errorMessage}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: viewModel.loadStations,
            child: Column(
                spacing: 16,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(AppLocalizations.of(context)!.nearbyStations,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  if (viewModel.locationPermission ==
                          LocationPermission.always ||
                      viewModel.locationPermission ==
                          LocationPermission.whileInUse)
                    Expanded(
                      child: ListView.builder(
                        itemCount: viewModel.isLoading
                            ? 5
                            : viewModel.nearbyStations.length,
                        itemBuilder: (context, index) {
                          if (viewModel.isLoading) {
                            return const NearbyCardSkeleton();
                          }
                          return nearbyCard(viewModel, index, context);
                        },
                      ),
                    )
                  else
                    locationNotLoaded(context, viewModel),
                ]),
          );
        },
      ),
    );
  }

  Widget nearbyCard(
      NearbyStopsViewModel viewModel, int index, BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final favoriteBorder = Theme.of(context).colorScheme.primaryContainer;

    final station = viewModel.nearbyStations[index];
    String formattedDistance = '';
    if (viewModel.currentLocation != null) {
      int distanceInMeters = calculateDistance(
              lat1: viewModel.currentLocation!.latitude,
              lon1: viewModel.currentLocation!.longitude,
              lat2: station.lat,
              lon2: station.long)
          .round();
      formattedDistance = MetricDistanceFormatter.formatDistance(
          distanceInMeters.toDouble(), context);
    }
    return Card(
      color: cardColor,
      child: ListTile(
        shape: RoundedRectangleBorder(
          side: viewModel.favouriteStations.contains(station)
              ? BorderSide(color: favoriteBorder, width: 3.0)
              : BorderSide.none,
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          station.name,
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (station.ref != null) ...[
              Text(station.ref!),
              const SizedBox(height: 5),
            ],
            StationLineLabels(station: station),
          ],
        ),
        isThreeLine: false,
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 80,
                  height: 25,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_pin),
                        const SizedBox(width: 5),
                        Text(
                          formattedDistance,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios_rounded),
          ],
        ),
        onTap: () {
          Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
          Provider.of<MapProvider>(context, listen: false)
              .updateLocation(LatLng(station.lat, station.long), 18);
          showBottomSheet(
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10.0))),
              context: context,
              builder: (context) => StationSheet(station: station));
        },
      ),
    );
  }

  Widget locationNotLoaded(
      BuildContext context, NearbyStopsViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(AppLocalizations.of(context)!.locationDisabled),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await viewModel.requestLocationPermission();
                if (viewModel.locationPermission == LocationPermission.always ||
                    viewModel.locationPermission ==
                        LocationPermission.whileInUse) {
                  await viewModel.loadStations();
                } else {
                  if (context.mounted) {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return LocationDeniedPopup();
                        });
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.enableLocation),
            ),
          ],
        ),
      ),
    );
  }
}
