import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:timelines/timelines.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TimelineSheet extends StatefulWidget {
  const TimelineSheet({super.key});

  @override
  State<TimelineSheet> createState() => _TimelineSheetState();
}

class _TimelineSheetState extends State<TimelineSheet> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: CacheManager.getAllStations(),
        builder: (context, stationSnapshot) {
          if (!stationSnapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return Consumer<TrackingProvider>(builder: (context, tracking, _) {
            if (tracking.stationsOnRoute == null) {
              return const CircularProgressIndicator();
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
                              style: const TextStyle(fontSize: 24)),
                        )),
                      ),
                      const Divider(thickness: 2),
                      Expanded(
                        child: Timeline.tileBuilder(
                          theme: TimelineThemeData(
                              color: Theme.of(context).colorScheme.primary),
                          builder: TimelineTileBuilder.fromStyle(
                            contentsAlign: ContentsAlign.basic,
                            indicatorStyle: IndicatorStyle.outlined,
                            oppositeContentsBuilder: (context, index) =>
                                Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                DateFormat("HH:mm").format(tracking
                                    .stationsOnRoute![index].scheduledArrival),
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            contentsBuilder: (context, index) => Padding(
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
                                    StationLineLabels(
                                        station: stationSnapshot.data!
                                            .firstWhere((element) =>
                                                element.id ==
                                                tracking.stationsOnRoute![index]
                                                    .stopId)),
                                  ],
                                ),
                              ),
                            ),
                            itemCount: tracking.stationsOnRoute!.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          });
        });
  }
}
