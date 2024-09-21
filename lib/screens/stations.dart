import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/bottom_sheets/station_sheet.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  TextEditingController searchController = TextEditingController();
  List<Station> cachedStations = [];
  bool onlyFavourites = false;

  @override
  void initState() {
    super.initState();
    CacheManager.getAllStations().then((value) {
      setState(() {
        cachedStations = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
        future: LocalStorageApi.getFavouriteStations(),
        builder: (context, favouriteSnapshot) {
          List<Station>? favourites;
          if (favouriteSnapshot.hasData &&
              favouriteSnapshot.data != null &&
              cachedStations.isNotEmpty) {
            favourites = favouriteSnapshot.data!
                .map((code) => cachedStations
                    .firstWhere((element) => element.code.toString() == code))
                .toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SearchBar(
                  controller: searchController,
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                        });
                      },
                    ),
                  ],
                  hintText: AppLocalizations.of(context)!.searchStation,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ChoiceChip.elevated(
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.0),
                        child: Text("All"),
                      ),
                      selected: !onlyFavourites,
                      onSelected: (value) => setState(() {
                        onlyFavourites = false;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip.elevated(
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(AppLocalizations.of(context)!.favourites),
                        ),
                        selected: onlyFavourites,
                        onSelected: favourites == null || favourites.isEmpty
                            ? null
                            : (value) => setState(() {
                                  onlyFavourites = true;
                                })),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Station>>(
                    future: cachedStations.isEmpty
                        ? Station.getAllStations()
                        : Future.value(cachedStations),
                    builder: (context, cachedSnapshot) {
                      if (cachedSnapshot.error != null) {
                        CacheManager.clearCache();
                        WidgetsBinding.instance
                            .addPostFrameCallback((timeStamp) {
                          setState(() {});
                        });
                      }

                      if (cachedStations.isEmpty &&
                          cachedSnapshot.data != null &&
                          cachedSnapshot.data!.isNotEmpty &&
                          !onlyFavourites &&
                          searchController.text.isEmpty) {
                        cachedStations = cachedSnapshot.data!;
                        CacheManager.setAllStations(cachedSnapshot.data!);
                      }

                      List<Station> stations = List.from(cachedStations);
                      List<Station> searchResults = [];
                      if (searchController.text.isNotEmpty) {
                        searchResults = stations
                            .where((station) =>
                                station.name
                                    .toLowerCase()
                                    .removePunctuation()
                                    .contains(searchController.text
                                        .toLowerCase()
                                        .removePunctuation()) ||
                                station.code
                                    .toString()
                                    .toLowerCase()
                                    .removePunctuation()
                                    .contains(searchController.text
                                        .toLowerCase()
                                        .removePunctuation()) ||
                                (station.ref != null
                                    ? station.ref!
                                        .toLowerCase()
                                        .removePunctuation()
                                        .contains(searchController.text
                                            .toLowerCase()
                                            .removePunctuation())
                                    : false))
                            .toList();
                      }

                      int? itemCount;

                      if (searchResults.isNotEmpty) {
                        stations.removeWhere(
                            (item) => !searchResults.contains(item));
                      }

                      if (onlyFavourites) {
                        stations
                            .removeWhere((item) => !favourites!.contains(item));
                      }

                      if (onlyFavourites && stations.isEmpty) {
                        onlyFavourites = false;
                        WidgetsBinding.instance
                            .addPostFrameCallback((timeStamp) {
                          setState(() {});
                        });
                      }

                      if (searchResults.isEmpty &&
                          searchController.text.isNotEmpty) {
                        itemCount = 1;
                      } else if (stations.isEmpty) {
                        itemCount = 10;
                      } else {
                        itemCount = stations.length;
                      }
                      return ListView.builder(
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (searchResults.isEmpty &&
                                searchController.text.isNotEmpty) {
                              return Card(
                                child: ListTile(
                                  title: Text(
                                      AppLocalizations.of(context)!.noResults),
                                ),
                              );
                            }
                            final station =
                                stations.isEmpty ? null : stations[index];

                            return Skeletonizer(
                              enabled: station == null,
                              child: Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  title: Text(station?.name ?? "Loading",
                                      style: const TextStyle(fontSize: 18)),
                                  subtitle: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        station?.code.toString() ?? "Loading",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(station?.ref ?? "")
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (favourites != null &&
                                          favourites.contains(station))
                                        IconButton(
                                            icon: Icon(Icons.star,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary),
                                            onPressed: () async {
                                              favourites?.remove(station);
                                              await LocalStorageApi
                                                  .setFavouriteStations(
                                                      favourites!
                                                          .map((e) =>
                                                              e.code.toString())
                                                          .toList());
                                              setState(() {});
                                            },
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary)
                                      else
                                        IconButton(
                                            icon:
                                                const Icon(Icons.star_outline),
                                            onPressed: () {
                                              if (station == null) return;
                                              favourites?.add(station);
                                              LocalStorageApi
                                                  .setFavouriteStations(
                                                      favourites!
                                                          .map((e) =>
                                                              e.code.toString())
                                                          .toList());
                                              setState(() {});
                                            }),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.arrow_forward_ios),
                                    ],
                                  ),
                                  onTap: () {
                                    if (station == null) return;
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    Provider.of<NavigationProvider>(context,
                                            listen: false)
                                        .setIndex(1);
                                    showBottomSheet(
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(10.0))),
                                        context: context,
                                        builder: (context) =>
                                            StationSheet(station: station));
                                    Provider.of<MapProvider>(context,
                                            listen: false)
                                        .updateLocation(
                                            LatLng(station.lat, station.long),
                                            18);
                                  },
                                ),
                              ),
                            );
                          });
                    }),
              )
            ],
          );
        });
  }
}
