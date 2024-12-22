import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/nearby/nearby_viewmodel.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
                        shrinkWrap: true,
                        itemCount: viewModel.nearbyStations.length,
                        itemBuilder: (context, index) {
                          final station = viewModel.nearbyStations[index];
                          int distanceInMeters = 0;
                          if (viewModel.currentLocation != null) {
                            distanceInMeters = calculateDistance(
                                    lat1: viewModel.currentLocation!.latitude,
                                    lon1: viewModel.currentLocation!.longitude,
                                    lat2: station.lat,
                                    lon2: station.long)
                                .round();
                          }
                          return Card(
                            surfaceTintColor:
                                Theme.of(context).colorScheme.tertiary,
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Skeletonizer(
                                enabled: viewModel.isLoading,
                                child: Text(
                                  station.name,
                                ),
                              ),
                              subtitle: Skeletonizer(
                                enabled: viewModel.isLoading,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context)!
                                        .distance(distanceInMeters)),
                                    const SizedBox(height: 5),
                                    StationLineLabels(station: station)
                                  ],
                                ),
                              ),
                              isThreeLine: false,
                              trailing:
                                  const Icon(Icons.arrow_forward_ios_rounded),
                              onTap: () {
                                Provider.of<NavigationProvider>(context,
                                        listen: false)
                                    .setIndex(1);
                                Provider.of<MapProvider>(context, listen: false)
                                    .updateLocation(
                                        LatLng(station.lat, station.long), 18);
                                showBottomSheet(
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(10.0))),
                                    context: context,
                                    builder: (context) =>
                                        StationSheet(station: station));
                              },
                            ),
                          );
                        },
                      ),
                    )
                  else
                    _locationNotLoaded(context, viewModel),
                ]),
          );
        },
      ),
    );
  }

  Widget _locationNotLoaded(
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
                          return _locationDeniedAlert(context);
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

  Widget _locationDeniedAlert(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.locationDeniedForever),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.locationDeniedText),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.locationDeniedAction),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel)),
        TextButton(
            onPressed: () => {openAppSettings(), Navigator.pop(context)},
            child: Text(AppLocalizations.of(context)!.goToSettings))
      ],
    );
  }
}
