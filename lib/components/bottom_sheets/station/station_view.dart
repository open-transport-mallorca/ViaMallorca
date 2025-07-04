import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/bottom_sheets/station/departure_card.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'station_viewmodel.dart';

class StationSheet extends StatefulWidget {
  final Station station;
  final int? highlightedDepartureId;

  const StationSheet(
      {super.key, required this.station, this.highlightedDepartureId});

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  Timer? _timer;
  StationSheetViewModel? _viewModel; // For the timer to access the view model

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNextUpdate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextUpdate() {
    _timer?.cancel();

    final now = DateTime.now();
    final nextMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final duration = nextMinute.difference(now);

    _timer = Timer(duration, () async {
      if (mounted) {
        await _viewModel?.fetchDepartures(); // Fetch data
        _scheduleNextUpdate(); // Schedule next update
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      return ChangeNotifierProvider(
        create: (_) => StationSheetViewModel(widget.station)..initialize(),
        child: Consumer<StationSheetViewModel>(
          builder: (context, viewModel, child) {
            _viewModel = viewModel;
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
                                        path:
                                            "${widget.station.lat},${widget.station.long}",
                                        query:
                                            "q=${widget.station.lat},${widget.station.long}",
                                      )),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                          favoritesProvider.isFavoriteStation(
                                                  widget.station.code
                                                      .toString())
                                              ? Icons.star
                                              : Icons.star_outline),
                                      onPressed: () {
                                        if (favoritesProvider.isFavoriteStation(
                                            widget.station.code.toString())) {
                                          favoritesProvider
                                              .removeFavoriteStation(widget
                                                  .station.code
                                                  .toString());
                                        } else {
                                          favoritesProvider.addFavoriteStation(
                                              widget.station.code.toString());
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "${widget.station.name} (${widget.station.code})",
                                        style: const TextStyle(fontSize: 24),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (widget.station.ref != null)
                                        Text(
                                          widget.station.ref!,
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 8),
                            StationLineLabels(station: widget.station),
                            const SizedBox(height: 16),
                            departuresList(context, viewModel),
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
    });
  }

  Widget departuresList(BuildContext context, StationSheetViewModel viewModel) {
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
                        station: widget.station,
                        departure: departure,
                        isHighlighted:
                            widget.highlightedDepartureId == departure.tripId,
                      ));
                });
              }),
        ),
      ),
    );
  }
}
