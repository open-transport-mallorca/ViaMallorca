import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:timelines/timelines.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

import 'timeline_viewmodel.dart';

class TimelineSheet extends StatelessWidget {
  const TimelineSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimelineSheetViewModel()..loadStations(),
      child: Consumer2<TimelineSheetViewModel, TrackingProvider>(
        builder: (context, viewModel, tracking, child) {
          // Handle station loading
          if (viewModel.isLoadingStations) {
            return const Center(child: CircularProgressIndicator());
          }

          final stations = viewModel.stations;

          if (stations == null || tracking.stationsOnRoute == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FittedBox(
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.stationsOnRoute,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    const Divider(thickness: 2),
                    Expanded(
                      child: Timeline.tileBuilder(
                        theme: TimelineThemeData(
                            color: Theme.of(context).colorScheme.primary),
                        builder: TimelineTileBuilder.fromStyle(
                          contentsAlign: ContentsAlign.basic,
                          indicatorStyle: IndicatorStyle.outlined,
                          oppositeContentsBuilder: (context, index) {
                            final scheduledArrival = tracking
                                .stationsOnRoute![index].scheduledArrival;
                            return Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                DateFormat("HH:mm").format(scheduledArrival),
                                style: const TextStyle(fontSize: 18),
                              ),
                            );
                          },
                          contentsBuilder: (context, index) {
                            final stopId =
                                tracking.stationsOnRoute![index].stopId;
                            final station = stations
                                .firstWhere((station) => station.id == stopId);

                            return Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      tracking.stationsOnRoute![index].stopName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    StationLineLabels(station: station),
                                  ],
                                ),
                              ),
                            );
                          },
                          itemCount: tracking.stationsOnRoute!.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
