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
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/station_sort.dart';
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
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ListTile(
                            leading: Icon(Icons.directions_bus),
                            title: Text(AppLocalizations.of(context)!.loading,
                                style: const TextStyle(fontSize: 20)),
                            subtitle: Text(
                              AppLocalizations.of(context)!.pleaseWait,
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: Icon(Icons.directions_bus),
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
                      child: departureCard(context, departure));
                });
              }),
        ),
      ),
    );
  }

  Widget departureCard(BuildContext context, Departure departure) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            spacing: 12,
            children: [
              // Leading icon (left side)
              _getIconForLine(departure.lineCode),

              // Main content (middle)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title line
                    Text(
                      "${departure.lineCode}${departure.destination != null ? " - ${departure.destination}" : ""}",
                      style: const TextStyle(fontSize: 20),
                    ),

                    // Subtitle content
                    Text(
                      departure.name,
                      style: const TextStyle(fontSize: 16),
                    ),

                    // Arrival time
                    Builder(
                      builder: (context) {
                        final minutesDifference = departure.estimatedArrival
                            .difference(DateTime.now())
                            .inMinutes;
                        final estimatedArrivalTime =
                            DateFormat.Hm().format(departure.estimatedArrival);
                        String arrivalText;
                        Color textColor;

                        if (minutesDifference < 0) {
                          arrivalText =
                              AppLocalizations.of(context)!.arrivingLate;
                          textColor = Theme.of(context).colorScheme.error;
                        } else if (minutesDifference > 59) {
                          arrivalText = estimatedArrivalTime;
                          textColor = Theme.of(context).colorScheme.onSurface;
                        } else {
                          arrivalText =
                              "$minutesDifference ${AppLocalizations.of(context)!.min} ($estimatedArrivalTime)";
                          textColor = Theme.of(context).colorScheme.onSurface;
                        }

                        return Text(
                          arrivalText,
                          style: TextStyle(fontSize: 14, color: textColor),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
                // Trailing widgets (right side)
                if (departure.realTrip != null) ...[
                  // Passenger count
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 20),
                      Text(
                        "${departure.realTrip?.stats.passengers}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  // Track button
                  Column(
                    spacing: 2,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final line =
                                await RouteLine.getLine(departure.lineCode);
                            if (context.mounted) {
                              Provider.of<MapProvider>(context, listen: false)
                                  .viewRoute(line, context, true);
                              Provider.of<TrackingProvider>(context,
                                      listen: false)
                                  .startTracking(
                                      departure.realTrip!.id,
                                      departure.lineCode,
                                      LatLng(departure.realTrip!.lat,
                                          departure.realTrip!.long),
                                      station.id);
                              Provider.of<MapProvider>(context, listen: false)
                                  .updateLocation(
                                      LatLng(departure.realTrip!.lat,
                                          departure.realTrip!.long),
                                      15);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                const Icon(Icons.location_pin, size: 20),
                                Text(
                                  AppLocalizations.of(context)!.track,
                                  style: const TextStyle(fontSize: 12),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        MetricDistanceFormatter.formatDistance(
                            calculateDistance(
                                lon1: station.long,
                                lat1: station.lat,
                                lon2: departure.realTrip!.long,
                                lat2: departure.realTrip!.lat),
                            context),
                        style: TextStyle(fontSize: 11),
                      )
                    ],
                  ),
                ],
              ])
            ],
          )),
    );
  }

  Icon _getIconForLine(String line) {
    if (line.startsWith("M")) {
      return const Icon(Icons.subway_outlined);
    } else if (line.startsWith("T")) {
      return const Icon(Icons.train);
    } else if (line.startsWith("A")) {
      return const Icon(Icons.airplanemode_active_outlined);
    } else {
      return const Icon(Icons.directions_bus);
    }
  }
}
