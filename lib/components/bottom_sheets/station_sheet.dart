import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StationSheet extends StatefulWidget {
  const StationSheet({super.key, required this.station});

  final Station station;

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  bool isFavourite = false;
  final int _numberOfDepartures = 10;

  @override
  void initState() {
    super.initState();

    // Check if the station is in the list of favourite stations
    // and update the isFavourite flag accordingly.
    LocalStorageApi.getFavouriteStations().then((value) {
      if (value.contains(widget.station.code.toString())) {
        if (mounted) {
          setState(() {
            isFavourite = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build the StationSheet widget.
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: FittedBox(
                            child: Text(
                                "${widget.station.name} (${widget.station.code})",
                                style: const TextStyle(fontSize: 24)))),
                    if (widget.station.ref != null) Text(widget.station.ref!),
                    const SizedBox(height: 16),
                    StationLineLabels(station: widget.station),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5),
                      child: FutureBuilder<List<Departure>>(
                          future: Departures.getDepartures(
                              stationCode: widget.station.code,
                              numberOfDepartures: _numberOfDepartures),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              // Show an error message if there was an error fetching the departures.
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Card(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .errorContainer,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: ListTile(
                                          title: Text(
                                              AppLocalizations.of(context)!
                                                  .info,
                                              style: const TextStyle(
                                                  fontSize: 24)),
                                          subtitle: Text(
                                            AppLocalizations.of(context)!
                                                .noDepartures,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 32)
                                ],
                              );
                            }
                            List<Departure> departures = snapshot.data ?? [];
                            return Skeletonizer(
                              enabled: departures.isEmpty,
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  setState(() {});
                                },
                                child: ListView.separated(
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    shrinkWrap: true,
                                    itemCount: departures.isEmpty
                                        ? 5
                                        : departures.length,
                                    itemBuilder: (context, index) {
                                      if (departures.isEmpty) {
                                        // Show a loading skeleton if there are no departures yet.
                                        return Card(
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(4.0),
                                                child: ListTile(
                                                  title: Text(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .loading,
                                                      style: const TextStyle(
                                                          fontSize: 20)),
                                                  subtitle: Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .pleaseWait,
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                )));
                                      }
                                      Departure departure = departures[index];
                                      return Consumer<TrackingProvider>(builder:
                                          (context, trackingProvider, _) {
                                        return Container(
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: trackingProvider
                                                              .trackingTripId ==
                                                          departure
                                                              .realTrip?.id &&
                                                      departure.realTrip != null
                                                  ? Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .tertiary
                                                          .withValues(alpha: 1),
                                                      width: 3)
                                                  : null),
                                          child: Card(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              child: ListTile(
                                                title: Text(
                                                    "${departure.lineCode}${departure.destination != null ? " - ${departure.destination}" : ""}",
                                                    style: const TextStyle(
                                                        fontSize: 20)),
                                                subtitle: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(departure.name,
                                                        style: const TextStyle(
                                                            fontSize: 16)),

                                                    // Display the estimated arrival time of the departure.
                                                    Text(
                                                      departure.estimatedArrival
                                                                  .difference(
                                                                      DateTime
                                                                          .now())
                                                                  .inMinutes <
                                                              0
                                                          ? AppLocalizations.of(
                                                                  context)!
                                                              .arrivingLate
                                                          : departure.estimatedArrival
                                                                      .difference(
                                                                          DateTime
                                                                              .now())
                                                                      .inMinutes >
                                                                  59
                                                              ? "${departure.estimatedArrival.hour}:${departure.estimatedArrival.minute < 10 ? "0" : ""}${departure.estimatedArrival.minute}"
                                                              : "${departure.estimatedArrival.difference(DateTime.now()).inMinutes} ${AppLocalizations.of(context)!.min} (${departure.estimatedArrival.hour}:${departure.estimatedArrival.minute < 10 ? "0" : ""}${departure.estimatedArrival.minute})",
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color: departure
                                                                      .estimatedArrival
                                                                      .difference(
                                                                          DateTime
                                                                              .now())
                                                                      .inMinutes <
                                                                  0
                                                              ? Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error
                                                              : Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onSurface),
                                                    ),
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (departure.realTrip !=
                                                        null) ...[
                                                      const SizedBox(width: 12),
                                                      Material(
                                                        color:
                                                            Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(50),
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(50),
                                                          onTap: () async {
                                                            final line =
                                                                await RouteLine
                                                                    .getLine(
                                                                        departure
                                                                            .lineCode);
                                                            if (context
                                                                .mounted) {
                                                              Provider.of<MapProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .viewRoute(
                                                                      line,
                                                                      context,
                                                                      true);
                                                              Provider.of<TrackingProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .startTracking(
                                                                      departure
                                                                          .realTrip!
                                                                          .id,
                                                                      departure
                                                                          .lineCode,
                                                                      LatLng(
                                                                          departure
                                                                              .realTrip!
                                                                              .lat,
                                                                          departure
                                                                              .realTrip!
                                                                              .long),
                                                                      widget
                                                                          .station
                                                                          .id);
                                                              Provider.of<MapProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .updateLocation(
                                                                      LatLng(
                                                                          departure
                                                                              .realTrip!
                                                                              .lat,
                                                                          departure
                                                                              .realTrip!
                                                                              .long),
                                                                      15);
                                                            }
                                                          },
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              const Icon(Icons
                                                                  .directions_bus),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(AppLocalizations
                                                                      .of(context)!
                                                                  .track),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                    }),
                              ),
                            );
                          }),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.directions),
                onPressed: () {
                  launchUrl(Uri.parse(
                      "https://www.google.com/maps/dir/?api=1&destination=${widget.station.lat},${widget.station.long}"));
                },
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: Icon(isFavourite ? Icons.star : Icons.star_outline),
                onPressed: () async {
                  List<String> favouriteStations =
                      await LocalStorageApi.getFavouriteStations();

                  if (isFavourite) {
                    favouriteStations.remove(widget.station.code.toString());
                  } else {
                    favouriteStations.add(widget.station.code.toString());
                  }
                  await LocalStorageApi.setFavouriteStations(favouriteStations);
                  setState(() {
                    isFavourite = !isFavourite;
                  });
                },
              ),
            ],
          ),
        )
      ],
    );
  }
}
