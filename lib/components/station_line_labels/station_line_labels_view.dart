import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' hide Consumer, Provider;
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'station_line_labels_viewmodel.dart';

class StationLineLabels extends ConsumerWidget {
  const StationLineLabels({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChangeNotifierProvider(
      create: (_) => StationViewModel(station)..loadLines(),
      child: Consumer<StationViewModel>(
        builder: (context, viewModel, child) {
          if (!viewModel.isDataLoaded) {
            return Skeletonizer(
              enabled: true,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  AppLocalizations.of(context)!.loading,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          final activeLines = viewModel.activeLines;

          if (activeLines.isEmpty) {
            return Padding(
                padding: const EdgeInsets.all(8.0), child: Container());
          }

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: activeLines.map((line) {
                  return Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        ref.read(navigationProvider.notifier).setIndex(1);
                        final routeLine = await RouteLine.getLine(line.code);
                        if (context.mounted) {
                          Provider.of<MapProvider>(context, listen: false)
                              .viewRoute(context, ref, line: routeLine);
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
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
