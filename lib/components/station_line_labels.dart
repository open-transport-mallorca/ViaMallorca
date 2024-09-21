import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StationLineLabels extends StatefulWidget {
  const StationLineLabels({super.key, required this.station});

  final Station station;

  @override
  State<StationLineLabels> createState() => _StationLineLabelsState();
}

class _StationLineLabelsState extends State<StationLineLabels> {
  List<RouteLine> cachedLines = [];

  @override
  void initState() {
    super.initState();
    CacheManager.getLines(widget.station.code).then((value) {
      setState(() {
        cachedLines = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteLine>>(
        future: cachedLines.isEmpty
            ? Station.getLines(widget.station.code)
            : Future.value(cachedLines),
        builder: (context, snapshot) {
          if (cachedLines.isEmpty &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            cachedLines = snapshot.data!;
            CacheManager.setLines(widget.station.code, cachedLines);
          }
          List<RouteLine> lines = snapshot.data ?? [];
          List<RouteLine> activeLines = [];
          for (var line in lines) {
            if (line.active) {
              activeLines.add(line);
            }
          }
          return Skeletonizer(
            enabled: activeLines.isEmpty,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                  activeLines.isNotEmpty ? activeLines.length : 1, (index) {
                if (activeLines.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        AppLocalizations.of(context)!.loading,
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontWeight: FontWeight.bold),
                      ));
                }
                RouteLine line = activeLines[index];
                return Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          Provider.of<NavigationProvider>(context,
                                  listen: false)
                              .setIndex(1);
                          final routeLine = await RouteLine.getLine(line.code);
                          if (context.mounted) {
                            Provider.of<MapProvider>(context, listen: false)
                                .viewRoute(routeLine, context);
                          }
                        },
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              line.code,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.bold),
                            ))));
              }),
            ),
          );
        });
  }
}
