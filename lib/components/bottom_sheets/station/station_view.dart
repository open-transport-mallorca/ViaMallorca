import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'station_viewmodel.dart';

class StationSheet extends StatelessWidget {
  final Station station;

  const StationSheet({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StationSheetViewModel(station)..initialize(),
      child: Consumer<StationSheetViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Text(
                            "${station.name} (${station.code})",
                            style: const TextStyle(fontSize: 24),
                          ),
                          if (station.ref != null) Text(station.ref!),
                          const SizedBox(height: 16),
                          StationLineLabels(station: station),
                          const SizedBox(height: 32),
                          _buildDeparturesList(context, viewModel),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.directions),
                      onPressed: () => launchUrl(Uri(
                          scheme: "geo",
                          path: "${station.lat},${station.long}",
                          query: "q=${station.lat},${station.long}")),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(viewModel.isFavourite
                          ? Icons.star
                          : Icons.star_outline),
                      onPressed: viewModel.toggleFavourite,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeparturesList(
      BuildContext context, StationSheetViewModel viewModel) {
    if (viewModel.hasError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 32.0),
        child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ListTile(
                title: Text(AppLocalizations.of(context)!.info,
                    style: const TextStyle(fontSize: 24)),
                subtitle: Text(
                  AppLocalizations.of(context)!.noDepartures,
                  style: TextStyle(
                      fontSize: 16, color: Theme.of(context).colorScheme.error),
                ),
              ),
            )),
      );
    }

    final departures = viewModel.departures ?? [];
    return RefreshIndicator(
      onRefresh: viewModel.fetchDepartures,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        child: Skeletonizer(
          enabled: departures.isEmpty,
          child: ListView.separated(
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              shrinkWrap: true,
              itemCount: departures.isEmpty ? 5 : departures.length,
              itemBuilder: (context, index) {
                if (departures.isEmpty) {
                  // Show a loading skeleton if there are no departures yet.
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ListTile(
                            title: Text(AppLocalizations.of(context)!.loading,
                                style: const TextStyle(fontSize: 20)),
                            subtitle: Text(
                              AppLocalizations.of(context)!.pleaseWait,
                              style: const TextStyle(fontSize: 16),
                            ),
                          )));
                }
                Departure departure = departures[index];
                return Consumer<TrackingProvider>(
                    builder: (context, trackingProvider, _) {
                  return Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: trackingProvider.trackingTripId ==
                                    departure.realTrip?.id &&
                                departure.realTrip != null
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withValues(alpha: 1),
                                width: 3)
                            : null),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ListTile(
                          title: Text(
                              "${departure.lineCode}${departure.destination != null ? " - ${departure.destination}" : ""}",
                              style: const TextStyle(fontSize: 20)),
                          subtitle: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(departure.name,
                                  style: const TextStyle(fontSize: 16)),

                              // Display the estimated arrival time of the departure.
                              Builder(
                                builder: (context) {
                                  final minutesDifference = departure
                                      .estimatedArrival
                                      .difference(DateTime.now())
                                      .inMinutes;
                                  final estimatedArrivalTime = DateFormat.Hm()
                                      .format(departure.estimatedArrival);
                                  String arrivalText;
                                  Color textColor;

                                  if (minutesDifference < 0) {
                                    arrivalText = AppLocalizations.of(context)!
                                        .arrivingLate;
                                    textColor =
                                        Theme.of(context).colorScheme.error;
                                  } else if (minutesDifference > 59) {
                                    arrivalText = estimatedArrivalTime;
                                    textColor =
                                        Theme.of(context).colorScheme.onSurface;
                                  } else {
                                    arrivalText =
                                        "$minutesDifference ${AppLocalizations.of(context)!.min} ($estimatedArrivalTime)";
                                    textColor =
                                        Theme.of(context).colorScheme.onSurface;
                                  }

                                  return Text(
                                    arrivalText,
                                    style: TextStyle(
                                        fontSize: 16, color: textColor),
                                  );
                                },
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (departure.realTrip != null) ...[
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(50),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(50),
                                    onTap: () async {
                                      final line = await RouteLine.getLine(
                                          departure.lineCode);
                                      if (context.mounted) {
                                        Provider.of<MapProvider>(context,
                                                listen: false)
                                            .viewRoute(line, context, true);
                                        Provider.of<TrackingProvider>(context,
                                                listen: false)
                                            .startTracking(
                                                departure.realTrip!.id,
                                                departure.lineCode,
                                                LatLng(departure.realTrip!.lat,
                                                    departure.realTrip!.long),
                                                station.id);
                                        Provider.of<MapProvider>(context,
                                                listen: false)
                                            .updateLocation(
                                                LatLng(departure.realTrip!.lat,
                                                    departure.realTrip!.long),
                                                15);
                                      }
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.directions_bus),
                                        const SizedBox(height: 4),
                                        Text(AppLocalizations.of(context)!
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
      ),
    );
  }
}
