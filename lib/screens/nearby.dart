import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/apis/location.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/bottom_sheets/station_sheet.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/utils/station_sort.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NearbyStops extends StatefulWidget {
  const NearbyStops({super.key});

  @override
  State<NearbyStops> createState() => _NearbyStopsState();
}

class _NearbyStopsState extends State<NearbyStops> {
  bool havePermission = false;

  LocationApi locationApi = LocationApi();

  List<Station> cachedStations = [];

  @override
  void initState() {
    super.initState();
    getLocationPermissions();
    CacheManager.getAllStations().then((value) {
      setState(() {
        cachedStations = value;
      });
    });
  }

  void getLocationPermissions() async {
    havePermission = await (locationApi.checkPermission()) ==
            LocationPermission.always ||
        await (locationApi.checkPermission()) == LocationPermission.whileInUse;
    setState(() {});
  }

  Future<bool> requestLocationPermissions() async {
    // Check if location permission is granted
    final locationPermission = await locationApi.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      final gotPermission = await locationApi.requestPermission();
      havePermission = gotPermission;
      setState(() {});
      return gotPermission;
    } else if (locationPermission == LocationPermission.deniedForever) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title:
                    Text(AppLocalizations.of(context)!.locationDeniedForever),
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
                      onPressed: () =>
                          {openAppSettings(), Navigator.pop(context)},
                      child: Text(AppLocalizations.of(context)!.goToSettings))
                ],
              );
            });
      }
    }

    setState(() {
      havePermission = locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse;
    });
    return havePermission;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            height: 16,
          ),
          SizedBox(
            width: double.infinity,
            child: Text(AppLocalizations.of(context)!.nearbyStations,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(
            height: 16,
          ),
          if (havePermission)
            Expanded(
              child: FutureBuilder<List<Station>>(
                  future: cachedStations.isEmpty
                      ? Station.getAllStations()
                      : Future.value(cachedStations),
                  builder: (context, snapshot) {
                    if (snapshot.error != null) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (cachedStations.isEmpty && snapshot.hasData) {
                      cachedStations = snapshot.data!;
                      CacheManager.setAllStations(snapshot.data!);
                    }
                    List<Station> stations = snapshot.data ?? [];
                    return FutureBuilder<Position>(
                        future: locationApi.getCurrentLocation(),
                        builder: (context, snapshot) {
                          Position? currentLocation = snapshot.data;
                          List<Station> nearbyStations = stations;
                          if (currentLocation != null) {
                            nearbyStations = StationSort.sortByDistance(
                                stations, currentLocation);
                          }
                          return SingleChildScrollView(
                            child: Column(
                                children: List.generate(
                              nearbyStations.length < 10
                                  ? nearbyStations.length
                                  : 10,
                              (index) {
                                int distanceInMeters = 0;
                                if (currentLocation != null) {
                                  distanceInMeters = calculateDistance(
                                          lat1: currentLocation.latitude,
                                          lon1: currentLocation.longitude,
                                          lat2: nearbyStations[index].lat,
                                          lon2: nearbyStations[index].long)
                                      .round();
                                }
                                return Card(
                                  surfaceTintColor:
                                      Theme.of(context).colorScheme.tertiary,
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    onTap: () {
                                      Provider.of<NavigationProvider>(context,
                                              listen: false)
                                          .setIndex(1);
                                      Provider.of<MapProvider>(context,
                                              listen: false)
                                          .updateLocation(
                                              LatLng(nearbyStations[index].lat,
                                                  nearbyStations[index].long),
                                              18);
                                      showBottomSheet(
                                          shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      top: Radius.circular(
                                                          10.0))),
                                          context: context,
                                          builder: (context) => StationSheet(
                                              station: nearbyStations[index]));
                                    },
                                    title: Skeletonizer(
                                      enabled: snapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          currentLocation == null,
                                      child: Text(
                                        stations[index].name,
                                      ),
                                    ),
                                    subtitle: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Skeletonizer(
                                            enabled: snapshot.connectionState ==
                                                    ConnectionState.waiting &&
                                                currentLocation == null,
                                            child: Text(AppLocalizations.of(
                                                    context)!
                                                .distance(distanceInMeters))),
                                        const SizedBox(height: 5),
                                        Skeleton.ignore(
                                            child: StationLineLabels(
                                                station: stations[index]))
                                      ],
                                    ),
                                    isThreeLine: false,
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios_rounded),
                                  ),
                                );
                              },
                            )),
                          );
                        });
                  }),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(AppLocalizations.of(context)!.locationDisabled),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        bool gotPermissions =
                            await requestLocationPermissions();
                        if (gotPermissions) {
                          setState(() {});
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.enableLocation),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
