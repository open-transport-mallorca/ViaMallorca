import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/bottom_sheets/station/departure_card.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'station_viewmodel.dart';

class StationSheet extends StatelessWidget {
  final Station station;
  final int? highlightedDepartureId;

  const StationSheet(
      {super.key, required this.station, this.highlightedDepartureId});

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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.directions),
                                    onPressed: () => launchUrl(Uri(
                                      scheme: "geo",
                                      path: "${station.lat},${station.long}",
                                      query: "q=${station.lat},${station.long}",
                                    )),
                                  ),
                                  IconButton(
                                    icon: Icon(viewModel.isFavourite
                                        ? Icons.star
                                        : Icons.star_outline),
                                    onPressed: viewModel.toggleFavourite,
                                  ),
                                ],
                              ),
                              Expanded(
                                // This helps to center the text in the available space
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${station.name} (${station.code})",
                                      style: const TextStyle(fontSize: 24),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (station.ref != null)
                                      Text(
                                        station.ref!,
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StationLineLabels(station: station),
                          const SizedBox(height: 16),
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
                      child: DepartureCard(
                        station: station,
                        departure: departure,
                        isHighlighted:
                            highlightedDepartureId == departure.tripId,
                      ));
                });
              }),
        ),
      ),
    );
  }
}
